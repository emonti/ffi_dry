# Here's a broader example which utilizes that arbitrary ':desc' parameter in a 
# "neighborly" way. This also demonstrates superclasses to add common struct
# features, declaring array fields, as well as nesting other structs.

    require 'rubygems'
    require 'ffi'
    require 'ffi/dry'

    class NeighborlyStruct < ::FFI::Struct
      include ::FFI::DRY::StructHelper

      def self.describe
        print "Struct: #{self.name}"
        dsl_metadata().each_with_index do |spec, i|
          print "  Field #{i}\n"
          print "    name:  #{spec[:name].inspect}\n"
          print "    type:  #{spec[:type].inspect}\n"
          print "    desc:  #{spec[:desc]}\n\n"
        end
        print "\n"
      end
      def describe;  self.class.describe;  end
    end

    class TestStruct < NeighborlyStruct
      dsl_layout do
        field   :field1,  :uint8,  :desc => "test field 1"
        field   :field2,  :uint8,  :desc => "test field 2"
      end
    end

    class SomeStruct < NeighborlyStruct
      dsl_layout do
        field  :kind, :uint8,      :desc => "a type identifier"
        struct :tst,  TestStruct,  :desc => "a nested TestStruct"
        field  :len,  :uint8,      :desc => "8-bit size value (>= self.size+2)"
        array  :str,  [:char,255], 
            :desc => "a string up to 255 bytes bound by :len"
      end

      # override kind getter method with our own
      # resolves kind to some kind of type array for example...
      def kind
        [:default, :bar, :baz][ self[:kind] ]
      end
    end

    s1=TestStruct.new
    s2=SomeStruct.new

    # check out that 'kind' override:
    s2.kind
    # => :default

    # oh and the regular FFI way is always intact
    s2[:kind]
    # => 0

    s2[:kind]=1
    s2.kind
    # => :bar

    s2.kind=3
    s2.kind
    # => :baz

    puts "*"*70
    s1.describe
    ## we get a dump of metadata
    # **********************************************************************
    # Struct: TestStruct  
    # Field 0
    #   name:  :field1
    #   type:  :uint8
    #   desc:  test field 1
    #
    # Field 1
    #   name:  :field2
    #   type:  :uint8
    #   desc:  test field 2

    puts "*"*70
    s2.describe
    ## we get a dump of metadata
    # Struct: SomeStruct  Field 0
    #     name:  :kind
    #     type:  :uint8
    #     desc:  a type identifier
    #
    #   Field 1
    #     name:  :tst
    #     type:  TestStruct
    #     desc:  a nested TestStruct
    #
    #   Field 2
    #     name:  :len
    #     type:  :uint8
    #     desc:  8-bit size value (>= self.size+2)
    #
    #   Field 3
    #     name:  :str
    #     type:  [:char, 255]
    #     desc:  a string up to 255 bytes bound by :len

    puts "*"*70
    s2.tst.describe
    ## same as s1.describe
    # **********************************************************************
    # Struct: TestStruct  
    # Field 0
    #   name:  :field1
    #   type:  :uint8
    #   desc:  test field 1
    #
    # Field 1
    #   name:  :field2
    #   type:  :uint8
    #   desc:  test field 2

