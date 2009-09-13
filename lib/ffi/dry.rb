begin; require 'rubygems'; rescue LoadError; end

require 'ffi'

module FFI::DRY
  
  # A module to add syntactic sugar and some nice automatic getter/setter
  # logic to FFI::Struct, FFI::ManagedStruct, etc.
  #
  # For example:
  #    require 'rubygems'
  #    require 'ffi'
  #    require 'ffi/dry'
  #    require 'pp'
  #
  #    class SomeStruct < FFI::Struct
  #      include FFI::DRY::StructHelper
  #
  #      # we get a new way of specifying layouts with a 'dsl'-like syntax
  #      dsl_layout do
  #        field   :field1,  :uint16, :desc => 'this is field 1'
  #        field   :field2,  :uint16, :desc => 'this is field 2'
  #      end
  #    end
  #
  #    ss0=SomeStruct.new
  #
  #    pp ss0.dsl_metadata   # we can look at definition metadata
  #
  #    # produces...
  #    #  [{:type=>:uint16, :name=>:field1, :desc=>"this is field 1"},
  #    #   {:type=>:uint16, :name=>:field2, :desc=>"this is field 2"}]
  #
  #    # And we have additional ways of instantiating and declaring values
  #    # during initialization. (The FFI standard ways still work too)
  #
  #    raw_data = "\x00\x00\xff\xff"
  #
  #    ss1=SomeStruct.new :raw => raw_data
  #    ss2=SomeStruct.new :raw => raw_data, :field1 => 1, :field2 => 2
  #    ss3=SomeStruct.new {|x| x.field1=1 }
  #    ss4=SomeStruct.new(:raw => raw_data) {|x| x.field1=1 }
  #
  #    [ ss0, 
  #      ss1, 
  #      ss2, 
  #      ss3, 
  #      ss4].each_with_index {|x,i| pp ["ss#{i}",[x.field1, x.field2]]}
  #
  #     # produces...
  #     # ["ss0", [0, 0]]
  #     # ["ss1", [0, 65535]]
  #     # ["ss2", [1, 2]]
  #     # ["ss3", [1, 0]]
  #     # ["ss4", [1, 65535]]
  #
  module StructHelper #< ::FFI::Struct

    attr_reader :dsl_metadata

    # Adds field setting on initialization to ::FFI::Struct.new as well as
    # a "yield(self) if block_given?" at the end.
    #
    # The field initialization kicks in if there is only one argument, and it 
    # is a Hash. 
    #
    # Note: 
    # The :raw parameter is a special tag in the hash. The value is taken as a 
    # string and initialized into a new FFI::MemoryPointer which this Struct 
    # then overlays.
    #
    # If your struct layout has a field named :raw field, it won't be 
    # assignable through the hash argument.
    #
    # See also: set_fields() which is called automatically on the hash, minus
    # the :raw tag.
    #
    def initialize(*args)
      if args.size == 1 and (oparams=args[0]).is_a? Hash
        params = oparams.dup
        if raw=params.delete(:raw)
          super( ::FFI::MemoryPointer.from_string(raw) )
        else
          super()
        end
        set_fields(params)
      else
        super(*args)
      end
      @dsl_metadata = self.class.dsl_metadata
      yield self if block_given?
    end

    # Sets field values in the struct specified by their symbolic name from a 
    # hash of ':field => value' pairs. Uses accessor field wrapper methods 
    # instead of a direct reference to the field (as in "obj.field1 = x", 
    # not "obj[:field] = x"). The difference is subtle, but this allows you
    # to take advantage of any wrapper methods you override when initializing
    # a new object. The only caveat is that the wrapper method must be named
    # the same as the field, and the field must be included in members() from
    # the layout.
    #
    # This method is called automatically if you are using the initialize() 
    # method provided in the DryStruct class and passing it a Hash as its only
    # argument.
    def set_fields(params)
      params.keys.each do |p|
        if members().include?(p)
          self.__send__(:"#{p}=", params[p])
        else
          raise(::ArgumentError, "#{self.class} does not have a '#{p}' field")
        end
      end
    end

    # Returns a new instance of self.class containing a seperately allocated 
    # copy of all our data. This abstract method should usually be called 
    # with super() from overridden 'copy' implementations for structures
    # containing pointers to other memory or variable length data at the end. 
    #
    # Note also that, by default, this implementation determine's size 
    # automatically based on the structure size. This is comparable to 
    # sizeof(some_struct) in C. However, you can supply a 'grown' parameter 
    # which can be used to add to the size of the copied instance as it is 
    # allocated and copied.
    def copy(grown=0)
      self.class.new( :raw => self.to_ptr.read_string(self.size+grown) )
    end

    # Returns a pointer to the specified field, which is the name assigned
    # to a member in the layout.
    def ptr_to(field)
      x = self[field] # this is actually a test, to raise if missing
      return (self.to_ptr + self.offset_of(field))
    end

    # Contains dsl_layout and some support methods that an 'includee' of
    # DryStructHelper will have available as class methods.
    module ClassMethods
      # returns the structure metadata for this class based on 
      # the dsl_layout definitions
      def dsl_metadata
        @dsl_metadata
      end

      private

      # This passes a block to an instance of DSL_StructLayoutBuilder, allowing
      # for a more declarative syntax.
      #
      # It is a replacement to layout() and stores the dsl_metadata gathered
      # about structure members locally.
      #
      #   
      def dsl_layout &block
        builder = DSL_StructLayoutBuilder.new(self)
        builder.instance_eval(&block)
        @layout = builder.build
        @size = @layout.size
        _class_do_dsl_metadata( builder.metadata )
        return @layout
      end

      def _class_do_dsl_metadata(meta)
        (@dsl_metadata = meta).each do |spec|
          name = spec[:name]
          type = spec[:type]
          define_method(:"#{name}") do 
            self[name]
          end unless instance_methods.include?(:"#{name}")
          define_method(:"#{name}=") do |val|
            self[name]=val
          end unless instance_methods.include?(:"#{name}=")
        end
      end
    end
    
    def self.included(base)
      base.extend(ClassMethods)
    end
  end # class StructHelper

  # This is a wrapper around the FFI::StructLayoutBuilder. Its goal is to 
  # provides a more declarative syntax for defining structures and include
  # the ability to attach arbitrary dsl_metadata information to structure 
  # fields during definition.
  #
  # The "DSL" (and that's really very in-quotes) supplies 3 ways to
  # define a field (for now):
  #
  #   field()
  #   array()
  #   struct()
  #
  # See the individual method descriptions for more info.
  #
  class DSL_StructLayoutBuilder
    attr_reader :builder, :metadata

    # Initializes the builder with a reference to the structure using it
    # Instead of duplicating Struct features, we just call back to them.
    def initialize(pbind)
      @pbind = pbind
      @builder = ::FFI::StructLayoutBuilder.new
      @metadata = []
      super()
    end

    # calls StructLayoutBuider.build() on the bulder and returns its
    # result.
    def build
      @builder.build
    end

    # Calls StructLayoutBuilder.add_struct() on the builder and stores
    # a metadata hash entry (the opts hash with name and type overridden)
    #
    #   struct field_name,  RubyClass, { ... metadata ... }
    #
    # :offset is a special key in metadata, specifies the offset of the field.
    def struct(name, klass, o={})
      unless klass.kind_of?(Class) and klass < ::FFI::Struct
        raise(::ArgumentError, "klass must be a struct")
      end

      opts = o.merge(:name => name, :type => klass)
      offset = opts[:offset]
      ret=@builder.add_struct(name, klass, offset)
      @metadata << opts
      return ret
    end

    # Calls StructLayoutBuider.add_array() on the builder and stores 
    # a metadata hash entry (the opts hash with name and type overridden)
    #
    # Syntax:
    #
    #   array field_name, [ctype, N], { ... metadata ... }
    #
    # :offset is a special key in metadata, specifies the offset of the field.
    def array(name, type, o={})
      unless type.kind_of?(::Array)
        raise(::ArgumentError, "type must be an array") 
      end

      opts = o.merge(:name => name, :type => type)
      offset = opts[:offset]
      mod = enclosing_module
      ret=@builder.add_array(name, find_type(type[0], mod), type[1], offset)
      @metadata << opts
      return ret
    end

    # Calls StructLayoutBuider.add_field() on the builder and stores 
    # a metadata hash entry (the opts hash with name and type overridden)
    #
    # Syntax:
    #
    #   field field_name, ctype, { ... metadata ... }
    #
    # :offset is a special key in metadata, specifies the offset of the field.
    def field(name, type, o={})
      opts = o.merge(:name => name, :type => type)
      offset = opts[:offset]
      mod = enclosing_module
      ret= @builder.add_field(name, find_type(type, mod), offset)
      @metadata << opts
      return ret
    end

    def find_type(*args)
      @pbind.find_type(*args)
    end

    def enclosing_module(*args)
      @pbind.enclosing_module(*args)
    end

  end

  # Used for creating various value <=> constant mapping namespace modules.
  module ConstMap

    def self.included(klass)
      klass.extend(ConstMap)
    end

    # A flexible lookup. Takes 'arg' as a Symbol or String as a name to lookup 
    # a value, or an Integer to lookup a corresponding name.
    def [](arg)
      if arg.is_a? Integer
        list.invert[arg]
      elsif arg.is_a? String or arg.is_a? Symbol
        list[arg.to_s.upcase]
      end
    end

    # Generates a hash of all the constant names mapped to value. Usually,
    # it's a good idea to override this like so in derived modules:
    #
    #   def list; @@list = super() ; end
    #
    def list
      constants.inject({}){|h,c| h.merge! c => const_get(c) }
    end

    private
      # When called from a module definition or class method, this method 
      # imports all the constants from # namespace 'nspace' that start with 
      # into the local namespace as constants named with whatever follows the 
      # prefix. Only constant names that match [A-Z][A-Z0-9_]+ are imported, 
      # the rest are ignored.
      #
      # This method also yields the (short) constant name and value to a block
      # if one is provided. The block works like [...].select {|c,v| ... } in
      # that the value is not mapped if the block returns nil or false.
      def slurp_constants(nspace, prefix)
        nspace.constants.grep(/^(#{prefix}([A-Z][A-Z0-9_]+))$/) do
          c = $2
          v = nspace.const_get($1)
          next if block_given? and not yield(c,v)
          const_set c, v
        end
      end
  end

  # Behaves just like ConstFlags, except that the [nnn] returns a list
  # of names for the flags set on nnn. Name string lookups work same way as 
  # ConstFlags.
  module ConstFlagsMap
    include ConstMap

    def self.included(klass)
      klass.extend(ConstFlagsMap)
    end

    # A flexible lookup. Takes 'arg' as a Symbol or String as a name to lookup 
    # a bit-flag value, or an Integer to lookup a corresponding names for the 
    # flags present in it.
    def [](arg)
      if arg.is_a? Integer
        ret = []
        list.invert.sort.each {|v,n| ret << n if (v & arg) == v }
        return ret
      elsif arg.is_a? String or arg.is_a? Symbol
        list[arg.to_s.upcase]
      end
    end
  end
end


