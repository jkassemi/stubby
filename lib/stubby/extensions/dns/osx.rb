# This module extracts the OS level DNS configuration dependency for OSX.
module Extensions
  module DNS
    module OSX
      private
        def servers_for(interface)
          servers = `networksetup -getdnsservers '#{interface}'`

          if servers =~ /There aren't any DNS Servers/
            return ["empty"]
          else
            return servers.split("\n")
          end
        end

        def setup_reference(interface)
          return if interface.include? "*"
          @network_interfaces[interface] = servers_for(interface)
          puts "[INFO] #{interface} configured with Stubby DNS. Will restore to #{@network_interfaces[interface]}"
          `networksetup -setdnsservers '#{interface}' #{STUBBY_MASTER}`
        end

        def teardown_reference(interface, servers)
          `networksetup -setdnsservers '#{interface}' #{servers.join(" ")}`
          puts "[INFO] #{interface} original DNS settings restored #{servers.join(" ")}"
        rescue => e
          puts e.inspect
        end

        def setup_references
          # TODO: if we connect to a new network, we'd like that to use us, too
          return if @network_interfaces

          @network_interfaces = {}
          `networksetup listallnetworkservices`.split("\n").each do |interface|
            next if interface.include? '*'
            setup_reference(interface)
          end

          flush
        end

        def teardown_references
          interfaces, @network_interfaces = @network_interfaces, nil

          (interfaces || []).each do |interface, servers| 
            teardown_reference(interface, servers)
          end

          flush
        end

        def flush
          `dscacheutil -flushcache`
        end
    end
  end
end
