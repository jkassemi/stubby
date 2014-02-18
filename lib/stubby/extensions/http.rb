require 'logger'
require 'sinatra/base'
require 'liquid'
require 'oj'
require 'pry'
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
          
          set :bind, session.host
          set :port, port
          set :stubby_session, session
          set :server, 'webrick'

          super(:server_settings => server_settings)
        end

        def adapter(name, &block)
          adapters[name] = block
        end

        def adapters
          @adapters ||= {}
        end
      end

      set :run, false
      set :static, false

      adapter "http-redirect" do
        url.scheme = "http"
        url.path = request.path if url.path.to_s.empty?
        redirect to(url.to_s)
      end

      adapter "https-redirect" do
        url.scheme = "https"
        url.path = request.path if url.path.to_s.empty?
        redirect to(url.to_s)
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

      adapter "default" do
        if url.path.empty?
          # Proxy all requests, preserve incoming path
          out = url.dup
          out.path = request.path
          request = HTTPI::Request.new
          request.url = out.to_s

          puts request.inspect

          response = HTTPI.get(request)

          response.headers.delete "transfer-encoding"
          response.headers.delete "connection"

          status(response.code)
          headers(response.headers)
          body(response.body)

        else
          # Proxy to the given path
          request = HTTPI::Request.new
          request.url = url.to_s

          response = HTTPI.get(request)

          response.headers.delete "transfer-encoding"
          response.headers.delete "connection"

          status(response.code)
          headers(response.headers)
          body(response.body)
        end
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
        @instruction ||= settings.stubby_session.search("http://#{request.host}")
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
          set :bind, session.host
          set :port, port
          set :stubby_session, session

          super(session, {
            :SSLEnable => true,
            :SSLCertName => %w[CN localhost]
          })
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
    end
  end
end

