module Stubby
  module Extensions
    class Default
      def initialize

      end    

      def run!(*args)

      end

      def stop!(*args)

      end

      def restore!(*args)

      end

      def expand_rule(trigger, instruction)
        # Default expansion:
        #     "example.com": "localhost:3000"
        #
        # => 
        #     "dns://example.com":    "@"
        #     "http://example.com":   "http-redirect://blank?to=https://example.com&code=302"
        #     "https://example.com":  "http-proxy://localhost:3000"
        #    
        #     "example.com:4000": "localhost:3000"
        #     
        # => 
        #     ERROR: port in trigger unsupported
        #
        #     "dns://example.com":      "@"
        #     "http://example.com:4000" 
        #
        #     "example.com": "http-redirect://localhost:3000"
        #
        # =>
        #     "dns://example.com":    "@"
        #     "http://example.com":   "http-redirect://?blank?to=http://localhost:3000&code=302"
        # =====================================
        #
        #   ".*\\.stubby.dev": "file:///var/www/tmp
        #
        #     =>
        #
        #   "dns://.*\\.stubby.dev": "@",
        #   "http://.*\\.stubby.dev": "file:///var/www/tmp",
        #   "https://.*\\.stubby.dev": "file:///var/www/tmp",
        scheme, remains = instruction.split("://")
        scheme, remains = remains, scheme if remains.nil?
   
        if scheme.nil?
          expand_bare(trigger, instruction)
        else
          expand_with_protocol(trigger, instruction)
        end
      end

      def expand_bare(trigger, instruction)
        {
          "dns://#{trigger}/a" => "dns-a://#{STUBBY_MASTER}",
          "http://#{trigger}" => "http-redirect://blank?to=https://#{trigger}&code=302",
          "https://#{trigger}" => "http-proxy://#{instruction}" 
        }
      end

      def expand_with_protocol(trigger, instruction)
        {
          "dns://#{trigger}/a" => "dns-a://#{STUBBY_MASTER}",
          "http://#{trigger}" => instruction,
          "https://#{trigger}" => instruction
        }
      end
    end
  end
end
