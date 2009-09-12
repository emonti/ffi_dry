require 'rubygems'
require 'ffi'
require 'ffi/dry'

class NeighborlyStruct < ::FFI::Struct
  include ::FFI::DRY::StructHelper

  def self.describe
    print "Struct: #{self.class}"
    dsl_metadata().each_with_index do |spec, i|
      print "  Field #{i}\n"+
            "    name:  #{spec[:name].inspect}\n"+
            "    type:  #{spec[:type].inspect}\n"+
            "    desc:  #{spec[:desc]}\n\n"
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
    array  :str,  [:char,255], :desc => "a string up to 255 bytes bound by :len"
  end

  # override kind getter method
  def kind
    [:default, :bar, :baz][ self[:kind] ]
  end
end

s1=TestStruct.new
s2=SomeStruct.new

puts "*"*70
s1.describe
puts "*"*70
s2.describe
