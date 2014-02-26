require 'logger'
require 'sinatra/base'
require 'liquid'
require 'httpi'
require 'rack/ssl'

module Extensions
  module HTTP
    class NotFoundException < Exception
    end

    class HTTPApp < Sinatra::Base
      class << self
        def port
          80
        end

        def run!(session, server_settings={})
          puts self.inspect + ": " + port.to_s
          
          set :bind, STUBBY_MASTER
          set :port, port
          set :stubby_session, session
          set :server, 'thin'

          super(:server_settings => server_settings)
        end

        def adapter(*names, &block)
          names.each do |name|
            adapters[name] = block
          end
        end

        def adapters
          @@adapters ||= {}
        end
      end

      set :run, false
      set :static, false

      adapter "http-redirect" do
        redirect to(instruction_params["to"])
      end

      adapter "file" do
        paths = []

        if url.host == "-"
          paths << File.expand_path(File.join("~/.stubby/#{request.host}", request.path))
          paths << File.expand_path(File.join("/usr/local/stubby/#{request.host}", request.path))
        else
          paths << File.expand_path(File.join(url.path, request.path))
        end

        paths.each do |path|
          next if path.index(url.path) != 0
          
          p = [path, File.join(path, "index.html")].select { |path|
            File.exists?(path) and !File.directory?(path)
          }.first

          send_file(p) and break unless p.nil?
        end

        not_found(paths.join(",\n"))
      end

      adapter "http-proxy" do
        url.scheme = "http"

        if url.path.empty?
          # Proxy all requests, preserve incoming path
          out = url.dup
          out.path = request.path
          request = HTTPI::Request.new
          request.url = out.to_s
        else
          # Proxy to the given path
          request = HTTPI::Request.new
          request.url = url.to_s
        end

        response = HTTPI.get(request)
        response.headers.delete "transfer-encoding"
        response.headers.delete "connection"

        status(response.code)
        headers(response.headers)
        body(response.body)

      end

      adapter "https-proxy" do
        url.scheme = "https"

        if url.path.empty?
          # Proxy all requests, preserve incoming path
          out = url.dup
          out.path = request.path
          request = HTTPI::Request.new
          request.url = out.to_s
        else
          # Proxy to the given path
          request = HTTPI::Request.new
          request.url = url.to_s
        end

        response = HTTPI.get(request)
        response.headers.delete "transfer-encoding"
        response.headers.delete "connection"

        status(response.code)
        headers(response.headers)
        body(response.body)

      end

      get(//) do
        if instruction.nil?
          not_found
        elsif adapter=self.class.adapters[url.scheme]
          instance_eval &adapter
        else
          instance_eval &self.class.adapters["default"]
        end
      end	

      private
      def forbidden
        [403, "Forbidden"]
      end

      def not_found(resource="*unknown*")
        [404, "Not Found:\n #{resource}"]
      end

      def instruction
        @instruction ||= MultiJson.load(HTTPI.post("http://#{STUBBY_MASTER}:9000/rules/search.json", 
          trigger: "#{request.scheme}://#{request.host}").body)
      end

      def instruction_params
        Rack::Utils.parse_nested_query url.query
      end

      def url
        @url ||= URI.parse(instruction)
      end
    end

    # TODO: get SSL support running. Self signed cert
    class HTTPSApp < HTTPApp
      use Rack::SSL

      class << self
        def port
          443
        end

        def run!(session)
          set :bind, STUBBY_MASTER
          set :port, port
          set :stubby_session, session

          #super(session, {
          #  :SSLEnable => true,
          #  :SSLCertName => %w[CN localhost]
          #})

          Rack::Handler::Thin.run(self, {
            :Host => STUBBY_MASTER,
            :Port => 443
          }) do |server|
            server.ssl = true
            server.ssl_options = {
              :verify_peer => false
            }
          end
        rescue => e
          puts "#{e.inspect}" 
        end
      end
    end

    class Server
      def initialize
        @log = Logger.new(STDOUT)
      end

      def run!(session, options)
        return if options[:http] == false

        @session = session
        HTTPApp.run!(session)
      end

      # http://blah.com => localhost:3000
      # =>
      # http://blah.com => http-proxy://localhost:3000
      def expand_rule(trigger, instruction, proto='http')
        u = URI.parse(instruction)
    
        (if u.scheme.nil?
          { trigger => "http-proxy://#{instruction}" }
        elsif u.scheme == "http"
          u.scheme = "http-proxy"
          { trigger => u.to_s }
        else
          { trigger => instruction }
        end).merge({
          "#{trigger.gsub(proto + "://", "dns://")}/a" => "dns-a://#{STUBBY_MASTER}"
        })
      end

      def stop!
        HTTPApp.quit!
      end
    end

    class SSLServer < Server
      def run!(session, options)
        return if options[:https] == false

        @session = session
        HTTPSApp.run!(session)
      end

      def stop!
        HTTPSApp.quit!
      end

      def expand_rule(trigger, instruction)
        super(trigger, instruction, "https")
      end
    end
  end
end

