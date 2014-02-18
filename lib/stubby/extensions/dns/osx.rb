# This module extracts the OS level DNS configuration dependency for OSX.
module Extensions
  module DNS
    module OSX
      private
        def setup_references
          return
          # TODO: if we connect to a new network, we'd like that to use us, too
          @network_interfaces = {}
          `networksetup listallnetworkservices`.split("\n").each do |interface|
            next if interface.include? '*'
            @network_interfaces[interface] = `networksetup -getdnsservers "#{interface}"`.split("\n")
            `networksetup -setdnsservers '#{interface}' #{@session.host}`
          end

          flush
        end

        def teardown_references
          return
          @network_interfaces.each do |interface, servers| 
            `networksetup -setdnsservers '#{interface}' #{servers.join(" ")}`
          end

          flush
        end

        def flush
          `dscacheutil -flushcache`
        end
    end
  end
end
