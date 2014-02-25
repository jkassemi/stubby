require 'sinatra/json'

module Stubby
  class Api < Sinatra::Base
    class << self
      attr_accessor :enabled_stubs
      attr_accessor :registry
      attr_accessor :environments, :environment

      def enabled_stubs
        @enabled_stubs ||= {} 
      end

      def registry
        @registry ||= Stubby::Registry.new
      end

      def reset
        @enabled_stubs = nil
        @environment = nil
        @registry = nil
      end

      def env_settings
        (@environments[environment] || {}).dup
      end

      def environment=(name)
        reset
        @environment = name

        (env_settings["dependencies"] || []).each do |depname, mode|
          activate(depname, mode)
        end

        env_settings.delete("dependencies")

        activate_transient(env_settings)
      end

      def activate(name, mode)
        registry_item = registry.latest(name)
        registry_item.install
        self.enabled_stubs[name] = registry_item.stub(mode)
      end

      def activate_transient(options, key="_")
        self.enabled_stubs[key] = TransientStub.new(options)
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
      json Hash[Api.enabled_stubs.collect { |name, stub|
        [name, stub.options]
      }]
    end

    post "/reset.json" do
      Api.reset
      json status: "ok"
    end

    get "/environment.json" do
      json environment: (Api.environment || "undefined")
    end

    post "/environment.json" do
      Api.environment = params[:environment]
      json status: "ok"
    end

    get "/environments.json" do
      json environments: Api.environments
    end

    post "/stubs/transient/activate.json" do
      Api.activate_transient(MultiJson.load(params[:options]), params[:key])
      json status: "ok"
    end

    post "/stubs/activate.json" do
      Api.activate(params[:name], params[:mode])
      json status: "ok"
    end

    post "/rules/search.json" do
      json Api.enabled_stubs.collect { |_, stub|
        stub.search(params[:trigger])
      }.compact.first
    end
  end

  class Master
    attr_accessor :extensions, :config

    def initialize(environments)
      @extensions = [
        Extensions::DNS::Server.new,
        Extensions::HTTP::Server.new,
        Extensions::HTTP::SSLServer.new,
        Extensions::SMTP::Server.new
      ]

      @config = Api
      @config.environments = environments
    end

    def environment=(environment)
      @config.environment = environment
    end

    def run!(options={})
      run_network do
        run_master do
          run_extensions
        end 
      end
    end

    private
    def run_network
      assume_network_interface
      yield
    ensure
      unassume_network_interface
    end

    def run_master
      $0 = "stubby: master"

      Api.run! do
        yield
      end
    end

    def run_extensions
      running.each do |process|
        Process.waitpid(process)
      end
    end

    def stop!
      puts "Shutting down..."

      Api.stop!

      running.each do |process|
        Process.kill("INT", process)
      end

      puts "Bye."
    end

    def running
      @running ||= run_extensions
    end

    def run_extensions
      @running_extensions ||= @extensions.collect { |plugin|
        Process.fork {
          $0 = "stubby: [extension worker] #{plugin.class.name}"
          plugin.run!(self, {})
        }
      }

      trap("INT") { 
        stop!
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
