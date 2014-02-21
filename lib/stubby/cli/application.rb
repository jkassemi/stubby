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
      desc "start MODE", "Starts stubby HTTP and DNS servers"
      def start(global_mode="development")
        unless File.exists?("Stubfile.json")
          puts "[ERROR]: Stubfile.json not found!"
          return
        end

        environments = Oj.load(File.read("Stubfile.json"))

        settings = environments[global_mode]

        if settings.nil?
          puts "[ERROR]: No #{global_mode} found. Try #{environments.keys.sort.inspect}"
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

        master = Stubby::Master.new

        # Install stubs we don't have
        # TODO: versioning syntax?
        (settings["dependencies"] || []).each do |name, mode|
          master.config.activate(name, mode)
        end

        File.write(File.expand_path("~/.stubby/pid"), Process.pid)

        master.run!
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
        if master_running?
          activated = Oj.parse(HTTPI.get("http://#{STUBBY_MASTER}:9000/stubs/activated.json").body)
        else
          activated = []
        end

        if name.nil?
          puts Oj.dump(activated)
        else
          puts Oj.dump(activated[name])
        end
      end

      private
      def master_running?
        Process.kill(0, File.read("~/stubby/pid"))
      rescue
        false
      end

      def permissions?
        `whoami`.strip == "root"
      end
    end
  end
end
