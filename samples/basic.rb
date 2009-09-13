#!/usr/bin/env ruby
# One major feature is a dsl"-like" syntax for declaring structure members
# in FFI::Struct or FFI::ManagedStruct definitions.
    
    require 'rubygems'
    require 'ffi'
    require 'ffi/dry'

    class SomeStruct < FFI::Struct
      include FFI::DRY::StructHelper

      # we get a new way of specifying layouts with a 'dsl'-like syntax
      # The hash containing {:desc => ... } can contain arbitrary keys which 
      # can be used however we like. dsl_metadata will contain all these
      # in the class and instance.
      dsl_layout do
        field   :field1,  :uint16, :desc => 'this is field 1'
        field   :field2,  :uint16, :desc => 'this is field 2'
      end
    end

    ss0=SomeStruct.new

# With the declaration above, we specified :desc hash value, which was stored
# in metadata along with the field name and type.

    pp ss0.dsl_metadata 
    [{:type=>:uint16, :name=>:field1, :desc=>"this is field 1"},
     {:type=>:uint16, :name=>:field2, :desc=>"this is field 2"}]
    # => nil


# We get some free additional ways of instantiating and declaring values during 
# initialization. (The FFI standard ways still work too)

    raw_data = "\x00\x00\xff\xff"

    ss1=SomeStruct.new :raw => raw_data
    ss2=SomeStruct.new :raw => raw_data, :field1 => 1, :field2 => 2
    ss3=SomeStruct.new {|x| x.field1=1 }
    ss4=SomeStruct.new(:raw => raw_data) {|x| x.field1=1 }

    [ ss0, 
      ss1, 
      ss2, 
      ss3, 
      ss4 ].each_with_index {|x,i| p ["ss#{i}",[x.field1, x.field2]]}

# which should produce...
# ["ss0", [0, 0]]
# ["ss1", [0, 65535]]
# ["ss2", [1, 2]]
# ["ss3", [1, 0]]
# ["ss4", [1, 65535]]

