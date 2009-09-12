require 'ffi/dry'
require 'socket'

module AddressFamily
  include FFI::DRY::ConstMap
  slurp_constants ::Socket, "AF_"
  def list ; @@list ||= super() ; end
end

# AddressFamily now has all the constants it found for Socket::AF_*
#
# i.e. AddressFamily::INET
#      AddressFamily::LINK
#      AddressFamily::INET6
#      etc...
#
# We can do quick lookups
#     AddressFamily[2]      # => "INET"
#     AddressFamily["INET"] # => 2
#
# We can get a hash of all key-value pairs with .list
#     AddressFamily.list
#     # => {"NATM"=>31, "DLI"=>13, "UNIX"=>1, "NETBIOS"=>33,  ...}
#
# ... which can be inverted for a reverse mapping
#     AddressFamily.list.invert
#     # => {16=>"APPLETALK", 5=>"CHAOS", 27=>"NDRV", 0=>"UNSPEC", ...}
#
