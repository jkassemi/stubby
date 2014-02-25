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
          body = HTTPI.post("http://#{STUBBY_MASTER}:9000/rules/search.json", 
            trigger: name).body

          instruction = MultiJson.load(body)

          if instruction.nil? or instruction == "@"
            unless name =~ /^dns-/
              process("dns-#{symbol_from_resource_class(resource_class)}://#{name}", 
                resource_class, transaction)
            else
              transaction.passthrough!(UPSTREAM)
            end

            return
          end

          url = URI.parse(instruction)

          if url.scheme.to_s.empty?
            url = URI.parse("dns-a://" + instruction)
          elsif (url.scheme.to_s =~ /^dns-.*/).nil?
            url.host = STUBBY_MASTER
          end

          response_resource_class = resource url.scheme.gsub('dns-', '')

          if url.host.to_s.empty?
            url.host = STUBBY_MASTER
          end

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
