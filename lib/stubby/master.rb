module Stubby
  class Api < Sinatra::Base
    class << self
      attr_accessor :enabled_stubs
      attr_accessor :registry

      def enabled_stubs
        @enabled_stubs ||= {} 
      end

      def registry
        @registry ||= Stubby::Registry.new
      end

      def activate(name, mode)
        registry_item = registry.latest(name)
        registry_item.install
        registry_item.stub(mode)
      end

      def activate_transient(options)
        self.enabled_stubs["_"] = TransientStub.new(options)
      end
    end

    set :bind, STUBBY_MASTER
    set :port, 9000
    set :run, false
    set :static, false

    get "/status" do
      json status: "ok"
    end

    get "/stubs/available.json" do
      json Api.registry.index
    end

    get "/stubs/activated.json" do
      json Api.enabled_stubs
    end

    post "/reset.json" do
      Api.enabled_stubs = nil
      Api.registry = nil      
      json status: "ok"
    end

    post "/stubs/transient/activate.json" do
      Api.activate_transient(params[:options])
      json status: "ok"
    end

    post "/stubs/activate.json" do
      Api.activate(params[:name], params[:mode])
      json status: "ok"
    end

    post "/rules/search.json" do
      json Api.enabled_stubs.detect { |_,stub|
        stub.search(params[:trigger])  
      }
    end
  end

  class Master
    attr_accessor :extensions, :config

    def initialize
      @extensions = [
        Extensions::DNS::Server.new,
        Extensions::HTTP::Server.new,
        Extensions::HTTP::SSLServer.new
      ]

      @config = Api
    end

    def run!(options={})
      begin
        assume_network_interface

        running.each do |process|
          puts "wait for #{process}"
          Process.waitpid(process)
        end
      ensure
        unassume_network_interface
      end
    end

    private
    def stop_extensions
      puts "Shutting down..."

      running.each do |process|
        Process.kill("INT", process)
      end

      puts "Bye."
    end

    def running
      @running ||= [run_master_api, run_extensions].flatten
    end

    def run_master_api
      Process.fork {
        $0 = "stubby: [config api]"
        Api.run!
      }
    end

    def run_extensions
      @running_extensions ||= @extensions.collect { |plugin|
        Process.fork {
          $0 = "stubby: [extension worker] #{plugin.class.name}"
          plugin.run!(self, {})
        }
      }

      trap("INT") { 
        stop_extensions
      }

      return @running_extensions
    end

    def assume_network_interface
      `ifconfig lo0 alias #{STUBBY_MASTER}`
    end

    def unassume_network_interface
      `ifconfig lo0 -alias #{STUBBY_MASTER}`
    end
  end
end
