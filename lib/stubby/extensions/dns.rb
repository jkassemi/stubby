require 'rubydns'
require 'ipaddress'
require 'uri'
require 'pry'

module Extensions
  module DNS
    class UnsupportedOS < Exception; end

    class Server < RubyDNS::Server
      UPSTREAM = RubyDNS::Resolver.new([[:udp, "8.8.8.8", 53], [:tcp, "8.8.8.8", 53]])
	    IN = Resolv::DNS::Resource::IN

      case RbConfig::CONFIG['host_os']
      when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
        raise UnsupportedOS, "Sorry, Windows is not currently supported"
      when /darwin|mac os/
        include Extensions::DNS::OSX
      when /linux/
        raise UnsupportedOS, "Sorry, Linux is not currently supported"
      else
        raise UnsupportedOS, "Sorry, #{RbConfig::CONFIG['host_os']} wasn't recognized"
      end

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

    		response_resource_class = resource url.scheme.gsub('dns-', '')

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

      def resource(pattern)
        return IN::A unless pattern.respond_to? :to_sym

        {
          a:      IN::A,
          aaaa:   IN::AAAA,
          srv:    IN::SRV,
          wks:    IN::WKS,
          minfo:  IN::MINFO,
          mx:     IN::MX,
          ns:     IN::NS,
          ptr:    IN::PTR,
          soa:    IN::SOA,
          txt:    IN::TXT,
          cname:  IN::CNAME
        }[pattern.to_sym] || IN::A
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
