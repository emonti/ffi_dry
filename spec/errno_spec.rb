require 'ffi/dry/errno'

module TestLib
  extend FFI::Library
  ffi_lib FFI::Library::LIBC
  attach_function :fopen, [:string, :string],  :pointer
end


describe  FFI::DRY::ErrnoHelper do
  it "should supply errno errors as exceptions" do
    filename = "/veryboguspath/bogus filename#{rand(0xffff)}"
    TestLib.fopen(filename, 'r').should be_null

    exc1 = FFI::DRY.errno_exception
    exc1.should be_kind_of(Errno::ENOENT)
  end

  it "should take an optional argument for additional error info" do
    filename = "/veryboguspath/bogus filename#{rand(0xffff)}"
    TestLib.fopen(filename, 'r').should be_null

    exc2 = FFI::DRY.errno_exception(filename)
    exc2.should be_kind_of(Errno::ENOENT)

    exc2.message.index(filename).should_not be_nil
  end


end
