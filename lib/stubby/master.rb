require 'sinatra/json'

module Stubby
  class Api < Sinatra::Base
    class << self
      attr_accessor :enabled_stubs
      attr_accessor :registry
      attr_accessor :master
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

        yield if block_given?
      end

      def env_settings
        (@environments[environment] || {}).dup
      end

      def environment=(name)
        reset do
          @environment = name

          (env_settings["dependencies"] || []).each do |depname, mode|
            activate(depname, mode)
          end

          env_settings.delete("dependencies")
          activate_transient(env_settings)
        end
      end

      def activate(source, mode)
        registry_item = RegistryItem.new(source)
        self.enabled_stubs[source] = registry_item.stub(mode)
      end

      def activate_transient(options, key="_")
        puts "Transient activation #{options.inspect}, #{key}"
        self.enabled_stubs[key] = TransientStub.new(options)
      end

      def expand_rules(options)
        options.inject({}) do |new_opts, (trigger, instruction)|
          if instruction.is_a? Hash # dependency modes
            new_opts[trigger] = instruction
          else 
            instruction = instruction.gsub("@", STUBBY_MASTER)

            protocol, url = trigger.split("://")
            url, protocol = protocol, :default if url.nil?

            extension = master.extensions[protocol.to_sym]

            if extension
              new_opts.delete(trigger)
              new_opts.merge!(extension.expand_rule(trigger, instruction))
            else
              raise "No `#{extension}` extension found for trigger: #{trigger}"
            end
          end

          new_opts
        end
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

    post "/stop.json" do
      Thread.new do
        sleep 1
        Process.kill("INT", Process.pid)
      end

      json status: "ok"
    end
  end

  class Master
    attr_accessor :extensions, :config

    def initialize(environments)
      @extensions = {
        default:    Stubby::Extensions::Default.new,
        dns:        Stubby::Extensions::DNS::Server.new,
        http:       Stubby::Extensions::HTTP::Server.new,
        https:      Stubby::Extensions::HTTP::SSLServer.new,
        smtp:       Stubby::Extensions::SMTP::Server.new
      }

      @config = Api
      @config.environments = environments
      @config.master = self
    end

    def environment=(environment)
      @config.environment = environment
    end

    def key(identifier)
      Digest::MD5.hexdigest(user_key + identifier)
    end

    def user_key
      @user_key ||= read_key
    end

    def environment
      @config.environment
    end

    def run!(options={})
      run_network do
        run_master do
          run_extensions
        end 
      end
    end

    def restore!
      restore_extensions
    end

    def stop!
      puts "Shutting down..."

      Api.stop!

      running.each do |process|
        Process.shutdown(process)
      end

      puts "Bye."
    end


    private
    def read_key
      File.read(keyfile)
    rescue
      generate_key
    end

    def generate_key
      SecureRandom.hex(50).tap do |key|
        File.write(keyfile, key)
      end
    end

    def keyfile
      File.expand_path("~/.stubby/key")
    end

    def run_network
      assume_network_interface
      yield
    ensure
      unassume_network_interface
    end

    def run_master
      $0 = "stubby: master"

      Api.run! do |server|
        yield
      end
    end

    def run_extensions
      running.each do |process|
        Process.waitpid(process)
      end
    end

    def restore_extensions
      @extensions.each do |name, plugin|
        plugin.restore!
      end
    end

    def running
      @running ||= run_extensions
    end

    def run_extensions
      @running_extensions ||= @extensions.collect { |name, plugin|
        Process.fork {
          $0 = "stubby: [extension worker] #{plugin.class.name}"
          plugin.run!(self, {})
        }
      }

      trap("INT", important: true) { 
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
