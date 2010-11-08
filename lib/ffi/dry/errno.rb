require 'ffi'

module FFI
  module DRY
    # This module lets us handle FFI-generated system call errors
    # through ruby as exceptions using the Errno and SystemCallError
    # exception classes.
    #
    # This module is not automatically included in the runtime when you
    # include 'ffi/dry'. You must explicitely say
    #
    #   require 'ffi/dry/errno'
    #
    module ErrnoHelper
      extend  FFI::Library
      libs = ffi_lib FFI::Library::LIBC

      attach_function :strerror, [:int], :string

      # Returns a ruby exception derived from the current value of errno.
      # As per the intro(2) manpage, this should only ever be called after an
      # error has been deteted from a function that sets the errno variable.
      def errno_exception
        err = self.errno
        return SystemCallError.new(strerror(err), err)
      end

      # An alias for FFI.errno
      def errno
        FFI.errno
      end

    end

    extend ErrnoHelper
  end
end
