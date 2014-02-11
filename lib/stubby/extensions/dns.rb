require 'rubydns'
require 'ipaddress'
require 'uri'
require 'pry'

module Extensions
  module DNS
    class Server < RubyDNS::Server
      UPSTREAM = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
	IN = Resolv::DNS::Resource::IN

      def process(name, resource_class, transaction)
		instruction = @session.search(name)

		if instruction.nil? or instruction == "@"
			transaction.passthrough!(UPSTREAM)
			return
		end

		url = URI.parse(instruction)

		if url.scheme.to_s.empty?
			url = URI.parse("dns-a://" + instruction)
		elsif (url.scheme.to_s =~ /^dns-.*/).nil?
			url.host = @session.host 
		end

		response_resource_class = {
			a: 	IN::A,
			aaaa: 	IN::AAAA,
			srv: 	IN::SRV,
			wks:	IN::WKS,
			minfo:	IN::MINFO,
			mx:	IN::MX,
			ns:	IN::NS,
			ptr:	IN::PTR,
			soa:	IN::SOA,
			txt: 	IN::TXT,
			cname: 	IN::CNAME
		}[url.scheme.gsub("dns-", "").to_sym] || IN::A

		if url.host.to_s.empty?
			url.host = @session.host
		end

		if !IPAddress.valid?(url.host) and response_resource_class == IN::A
			response_resource_class = IN::CNAME
		end

		response = url.host

		if response_resource_class == IN::CNAME
			response = Resolv::DNS::Name.create(url.host)
		end

		puts "DNS: #{name} => #{response}-#{resource_class.name})"

		transaction.respond!(response, 
			:resource_class => response_resource_class, 
			:ttl => 0)
      end

      def run!(session)
        @session = session
        setup_references and run_dns_server
      end

      def stop!
        teardown_references and stop_dns_server
      end

      private
      def setup_references
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
        @network_interfaces.each do |interface, servers| 
          `networksetup -setdnsservers '#{interface}' #{servers.join(" ")}`
        end

        flush
      end

      def flush
        `dscacheutil -flushcache`
      end

      def run_dns_server
        logger.level = Logger::INFO

        EventMachine.run do
          run(:listen => [[:tcp, @session.host, 53],
            [:udp, @session.host, 53]])
        end
      end

      def stop_dns_server
        fire :stop
        EventMachine::stop_event_loop
      rescue
      end
    end
  end
end
