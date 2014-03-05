require 'rubydns'
require 'ipaddress'
require 'uri'

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
          body = HTTPI.post("http://#{STUBBY_MASTER}:9000/rules/search.json", 
            trigger: "dns://#{name}/#{symbol_from_resource_class(resource_class)}").body

          instruction = MultiJson.load(body)

          if instruction.nil? or instruction == "@"
            transaction.passthrough!(UPSTREAM)
            return
          end

          url = URI.parse(instruction)

          response_resource_class = resource url.scheme.gsub('dns-', '')

          if !IPAddress.valid?(url.host) and response_resource_class == IN::A
            response_resource_class = IN::CNAME
          end

          response = url.host

          if [IN::CNAME, IN::MX].include? response_resource_class
            response = Resolv::DNS::Name.create(url.host)
          end

          puts "DNS: #{name} => #{response}-#{resource_class.name})"

          if response_resource_class == IN::MX
            transaction.respond!(10, response,
              :resource_class => response_resource_class,
              :ttl => 0)
          else
            transaction.respond!(response, 
              :resource_class => response_resource_class, 
              :ttl => 0)
          end
      end

      def run!(session, options)
        return if options[:dns] == false
        trap("INT"){ stop! }

        @session = session
        setup_references and run_dns_server
      end

      def stop!
        teardown_references and stop_dns_server
      end

      def restore!
        restore_references
      end

      def expand_rule(trigger, instruction)
        i = URI.parse(instruction)
        t = URI.parse(trigger)

        # If not specifying a record type, match a
        t.path = "/a" if t.path.empty?
    
        if i.scheme.nil?
          { t.to_s => "dns-a://#{instruction}" }
        else
          { t.to_s => instruction }
        end
      end
      
      private

      def resource(pattern)
        return IN::A unless pattern.respond_to? :to_sym
        symbol_to_resource_class[pattern.to_sym] || IN::A
      end

      def symbol_from_resource_class(klass)
        symbol_to_resource_class.invert[klass] || :a
      end

      def symbol_to_resource_class
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
        }
      end

      def run_dns_server
        logger.level = Logger::INFO

        EventMachine.run do
          run(:listen => [[:tcp, STUBBY_MASTER, 53],
            [:udp, STUBBY_MASTER, 53]])
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
