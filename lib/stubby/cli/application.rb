require 'thor'

require 'stubby/registry'
require 'stubby/session'
require 'stubby/extensions/dns'
require 'stubby/extensions/http'

module Stubby
  module CLI
    class Application < Thor
      default_task :start

      # TODO: filesystem watch all config directories for change
      desc "start ENVIRONMENT", "Starts stubby HTTP and DNS servers"
      def start(environment="development")
        unless File.exists?("Stubfile.json")
          puts "[ERROR]: Stubfile.json not found!"
          return
        end

        unless permissions?
          puts "[ERROR]: ATM I need to be run with sudo..."
          return
        end

        if master_running?
          puts "[ERROR]: Stubby's already running!"
          return
        end

        environments = Oj.load(File.read("Stubfile.json"))

        File.write(pidfile, Process.pid)

        master = Stubby::Master.new(environments)
        master.environment = environment
        master.run!
      end

      desc "env", "Switch stubby environment"
      def env(name=nil)
        unless master_running?
          puts "[ERROR]: Stubby must be running to run 'environment'"
          return
        end

        if name == nil
          environment = Oj.load(HTTPI.get("http://#{STUBBY_MASTER}:9000/environment.json").body)["environment"]
          environments = Oj.load(HTTPI.get("http://#{STUBBY_MASTER}:9000/environments.json").body)

          puts Oj.dump("current" => environment, "available" => environments["environments"])
        else
          puts HTTPI.post("http://#{STUBBY_MASTER}:9000/environment.json", environment: name).body
        end
      end
    
      desc "search", "View all available stubs"
      def search(name=nil)
        if master_running?
          available = Oj.parse(HTTPI.get("http://#{STUBBY_MASTER}:9000/stubs/available.json").body)
        else
          available = Stubby::Api.registry.index
        end

        if name.nil?
          puts Oj.dump(available)
        else
          puts Oj.dump(available[name])
        end
      end

      desc "status NAME", "View current status for stub NAME"
      def status(name=nil)
        environment = Oj.load(HTTPI.get("http://#{STUBBY_MASTER}:9000/environment.json").body)["environment"]
        environments = Oj.load(HTTPI.get("http://#{STUBBY_MASTER}:9000/environments.json").body)

        if master_running?
          activated = Oj.load(HTTPI.get("http://#{STUBBY_MASTER}:9000/stubs/activated.json").body)
        else
          puts "[ERROR] - Stubby currently not running"
          return
        end

        if name.nil?
          puts Oj.dump("rules" => activated, "available" => environments, "environment" => environment)
        else
          puts Oj.dump("rules" => activated[name], "available" => environments, "environment" => environment)
        end
      end

      private
      def pidfile
        @pidfile ||= File.expand_path("~/.stubby/pid")
      end

      def master_running?
        Process.kill(0, File.read(pidfile).to_i)
      rescue
        false
      end

      def permissions?
        `whoami`.strip == "root"
      end
    end
  end
end
