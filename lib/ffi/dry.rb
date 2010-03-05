begin; require 'rubygems'; rescue LoadError; end

require 'ffi'

unless defined?(FFI::Library::LIBC)
  FFI::Library::LIBC = (RUBY_PLATFORM == 'mswin32' ?  'msvcrt' : 'c')
end

module FFI::DRY
  
  # A module to add syntactic sugar and some nice automatic getter/setter
  # methods to FFI::Struct, FFI::ManagedStruct, etc.
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
  module StructHelper

    attr_reader :dsl_metadata

    # Allows setting structure fields on initialization to ::FFI::Struct.new 
    # as well as a "yield(self) if block_given?" at the end.
    #
    # Field initialization happens if there is only one argument and it is
    # a Hash. 
    #
    # The params hash is taken as a set of values for fields where the hash 
    # keys specify the field names to set.
    #
    # @param [Hash] params
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
      @dsl_metadata = self.class.dsl_metadata
      params=nil

      if args.size == 1 and (oparams=args[0]).is_a? Hash
        params = oparams.dup
        if raw=params.delete(:raw)
          super( ::FFI::MemoryPointer.new(raw.size).write_string(raw) )
        else
          super()
        end
      else
        super(*args)
      end

      set_fields(params)
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
    # method provided in the Struct class and passing it a Hash as its only
    # argument.
    def set_fields(params=nil)
      (params || {}).keys.each do |p|
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
      self.class.new( :raw => self.to_ptr.read_string(self.copy_size+grown) )
    end

    # This method is called when creating a copy of self. It can be overridden
    # by derived structures to return another size. This is sometimes done
    # to account for alignment issues, etc.
    def copy_size
      self.size
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

      def define_field_accessor name, &block
        if instance_methods.include?("#{name}")
          warn "WARNING: The name '#{name}' is in use for class #{self} "+
               "Skipping automatic method creation in dsl_layout block."
        else
          define_method name, &block
        end
      end

      # This passes a block to an instance of DSLStructLayoutBuilder, allowing
      # for a more declarative syntax with additional metadata to be included.
      #
      # dsl_layout() a replacement to layout() and stores the dsl_metadata 
      # gathered about structure members locally and automatically creates
      # accessor methods for each field in the structure.
      #
      # NOTE if a structure field name conflicts with another instance method 
      # already defined in the class, the relevant accessor method is not 
      # created and a warning is issued. This does not apply to methods
      # defined after the dsl_layout block is called. In other words this
      # does not affect the overriding of accessor methods in any way.
      def dsl_layout &block
        builder = DSLStructLayoutBuilder.new(self)
        builder.instance_eval(&block)
        @layout = self.layout(*(builder.__layout_args))
        @size = @layout.size
        _class_meths_from_dsl_metadata( builder.__metadata )
        return @layout
      end

      def _class_meths_from_dsl_metadata(meta)
        (@dsl_metadata = meta).each do |spec|
          name = spec[:name]
          ftype = spec[:type]
          if p=spec[:p_struct] and p.kind_of?(Class)
            define_field_accessor(:"#{name}") do
              p.new(self[name]) unless self[name].null?
            end
          else
            define_field_accessor(:"#{name}") { self[name] }
          end

          define_field_accessor(:"#{name}=") {|val| self[name]=val }
        end
      end
    end
    
    def self.included(base)
      base.extend(ClassMethods)
    end

  end # class StructHelper

  # This class provides the DSL for StructHelper.dsl_layout.
  # You probably don't want to use this directly but if you do, to use the DSL,
  # you may either pass a structure definition into 'instance_eval' or 
  # call methods on the object. The methods __metadata and __layout_args return
  # structure information back to the caller, which can use them to create
  # a new structure.
  class DSLStructLayoutBuilder
    attr_reader :__metadata, :__layout_args

    # Initializes the a new builder class. 
    def initialize(pbind)
      @pbind = pbind
      @__layout_args = []
      @__metadata = []
      yield self if block_given?
    end

    # A pointer to a structure. The structure does not allocate the entire
    # space for the structure pointed to, just a pointer. When calling the 
    # accessor for a p_struct field, a new instance of the FFI::Struct type
    # for the pointer will be returned.
    def p_struct(name, klass, o={})
      unless klass.kind_of?(Class)
        raise(TypeError, "klass must be a Class")
      end
      opts = o.merge(:p_struct => klass)
      offset = opts[:offset]
      field(name, :pointer, opts)
    end

    # Declaratively adds a field to the structure.
    #
    # Syntax:
    #
    #   field field_name, ctype, { ... metadata ... }
    #
    # :offset is a special key in metadata, specifies the offset of the field.
    def field(name, type, o={})
      opts = o.merge(:name => name, :type => type)
      offset = opts[:offset]

      @__layout_args << name
      @__layout_args << type
      @__layout_args << offset if offset

      @__metadata << opts
      return opts
    end

    alias array field
    alias struct field
    alias union field

    # Experimental - Allows specifying structure fields by taking a missing 
    # method name as field name for the structure.
    def method_missing(name, type, *extra)
      o={}
      if extra.size > 1
        raise(ArgumentError, 
          "Bad field syntax. Use: 'name :type, {optional extra parameters}'")
      elsif h=extra.first
        if h.kind_of? Hash
          o=h
        else
          raise(TypeError, "Options must be provided as a hash.")
        end
      end
      opts = o.merge(:name => name, :type => type)
      offset = opts[:offset]

      @__layout_args << name
      @__layout_args << type
      @__layout_args << offset if offset

      @__metadata << opts
      return opts
    end
  end # DSLStructLayoutBuilder

  # ConstMap can be used to organize and lookup value to constant mappings and
  # vice versa. Constants can be imported from a namespace based on a regular
  # expression or other means.
  module ConstMap

    def self.included(klass)
      klass.extend(ConstMap)
    end

    # A flexible name to value lookup. 
    #
    # @param [String, Symbol, Integer] arg
    #   Use a Symbol or String as a name to lookup its value. Use an 
    #   Integer to lookup the corresponding name.
    #
    def [](arg)
      if arg.is_a? Integer
        list.invert[arg]
      elsif arg.is_a? String or arg.is_a? Symbol
        list[arg.to_s.upcase]
      end
    end

    # Generates a hash of all the constant names mapped to value. Usually,
    # it's a good idea to override this like so to cache results in 
    # derived modules:
    #
    #   def list; @@list ||= super() ; end
    #
    def list
      constants.inject({}){|h,c| h.merge! c => const_get(c) }
    end

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
  end # ConstMap

  # Behaves just like ConstFlags, except that it returns a list
  # of names for the flags. Name string lookups work same way as 
  # ConstFlags.
  module ConstFlagsMap
    include ConstMap

    def self.included(klass)
      klass.extend(ConstFlagsMap)
    end

    # A flexible lookup method for name to bit-flag mappings.
    #
    # @param [String, Symbol, Integer] arg
    #   Symbol or String as a name to lookup a bit-flag value, or an 
    #   Integer to lookup a corresponding names for the flags present in it.
    def [](arg)
      if arg.is_a? Integer
        ret = []
        if arg == 0
          n = list.invert[0]
          ret << n if n
        else
          list.invert.sort.each {|v,n| ret << n if v !=0 and (v & arg) == v }
        end
        return ret
      elsif arg.is_a? String or arg.is_a? Symbol
        list[arg.to_s.upcase]
      end
    end
  end # ConstFlagsMap


  module NetEndian
    extend ::FFI::Library

    ffi_lib FFI::Library::LIBC
    begin; ffi_lib 'wsock32'; rescue LoadError; end

    attach_function :htons, [:uint16], :uint16
    attach_function :ntohs, [:uint16], :uint16
    attach_function :htonl, [:uint32], :uint32
    attach_function :ntohl, [:uint32], :uint32

    I16_convert = [method(:ntohs), method(:htons)]
    I32_convert = [method(:ntohl), method(:htonl)]

    ENDIAN_METHS = {
      ::FFI.find_type(:int16)  => I16_convert,
      ::FFI.find_type(:uint16) => I16_convert,
      ::FFI.find_type(:int32)  => I32_convert,
      ::FFI.find_type(:uint32) => I32_convert,
    }
  end # NetEndian


  # A special helper for network packet structures that use big-endian or
  # "network" byte-order. This helper generates read/write accessors that
  # automatically call the appropriate byte conversion function, ntohs/ntohl
  # for 'reading' a 16/32 bit field, and htons/htonl for writing to one.
  #
  # NOTE this helper does not currently do anything special for 64-bit or
  # higher values but this might be added at some point if the need arises.
  #
  # NOTE unlike the StructHelper module, no special relevance is given
  # to fields with a ":p_struct" option or defined with the p_struct DSL 
  # method.  These are ignored and treated like any other field. A net struct 
  # generally doesn't contain pointers into native memory anyway.
  module NetStructHelper
    def self.included(base)
      base.instance_eval { include StructHelper }
      base.extend(ClassMethods)
    end

    module ClassMethods

      private

      def _class_meths_from_dsl_metadata(meta)
        (@dsl_metadata = meta).each do |spec|
          name = spec[:name]
          type = spec[:type]

          # Create endian swapper accessors methods for each applicable
          # field
          if( type.kind_of?(Symbol) and 
            cnv=NetEndian::ENDIAN_METHS[ ::FFI.find_type(type) ] )
            define_method(:"#{name}"){ cnv[0].call(self[name]) }
            define_method(:"#{name}="){|val| self[name] = cnv[1].call(val) }
          else
            define_field_accessor(:"#{name}"){ self[name] } 
            define_field_accessor(:"#{name}="){|val| self[name]=val }
          end

        end
      end
    end
  end # NetStructHelper

end # FFI::DRY

