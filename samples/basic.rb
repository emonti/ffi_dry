require 'rubygems'
require 'ffi'
require 'ffi/dry'

class SomeStruct < FFI::Struct
  include FFI::DRY::StructHelper

  # we get a new way of specifying layouts with a 'dsl'-like syntax
  dsl_layout do
    field   :field1,  :uint16, :desc => 'this is field 1'
    field   :field2,  :uint16, :desc => 'this is field 2'
  end
end


ss0=SomeStruct.new

p ss0.dsl_metadata   # we can look at definition metadata

# And we have additional ways of instantiating and declaring values
# during initialization. (The FFI standard ways still work too)

raw_data = "\x00\x00\xff\xff"

ss1=SomeStruct.new :raw => raw_data
ss2=SomeStruct.new :raw => raw_data, :field1 => 1, :field2 => 2
ss3=SomeStruct.new {|x| x.field1=1 }
ss4=SomeStruct.new(:raw => raw_data) {|x| x.field1=1 }

[ ss0, 
  ss1, 
  ss2, 
  ss3, 
  ss4].each_with_index {|x,i| p ["ss#{i}",[x.field1, x.field2]]}

