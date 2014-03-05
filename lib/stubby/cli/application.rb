require 'stubby/registry'
require 'stubby/extensions/dns'
require 'stubby/extensions/http'

module Stubby
  module CLI
    class Application < Thor
      default_task :start

      # TODO: filesystem watch all config directories for change
      desc "start ENVIRONMENT", "Starts stubby HTTP and DNS servers"
      option :stubfile, default: "Stubfile.json"
      long_desc <<-LONGDESC
        > $ sudo stubby start [ENVIRONMENT='development']

        Starts the stubby HTTP and DNS servers and loads the configuration
        from `Stubfile.json` for the named environment. If no environment
        is given, we default to 'development'

        An environment need not actually match a name in `Stubfile.json`.
        This allows you to use environments named in dependencies but not
        in the application. If no rules match the environment, Stubby 
        just won't override any behaviors.
      LONGDESC

      def start(environment="development")
        stubfile = File.expand_path(options[:stubfile])

        unless File.exists?(stubfile)
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

        environments = MultiJson.load(File.read(stubfile))

        File.write(pidfile, Process.pid)

        master = Stubby::Master.new(environments)
        master.environment = environment
        master.run!
      end

      desc "halt", "Shut down if running, restore if not"
      def halt
        if master_running?
          stop
        else
          restore
        end
      end

      desc "stop", "Stops a running stubby process"
      def stop
        if master_running?
          Process.kill("INT", File.read(pidfile).to_i)

          while master_running?
            puts "." and sleep 1
          end 
        end
      end

      desc "restore", "Restore defaults"
      def restore
        if master_running?
          puts "[ERROR] Stubby needs to be shut down first"
          exit
        end

        master = Stubby::Master.new({})
        master.restore!
      end

      desc "env NAME", "Switch stubby environment"
      long_desc <<-LONGDESC
        > $ sudo stubby env test
        > {"status":"ok"}
      LONGDESC
      def env(name=nil)
        unless master_running?
          puts "[ERROR]: Stubby must be running to run 'environment'"
          return
        end

        puts HTTPI.post("http://#{STUBBY_MASTER}:9000/environment.json", environment: name).body
      end
    
      desc "status", "View current rules"
      long_desc <<-LONGDESC
        > $ sudo bin/stubby status
        > {
        >   "rules":{
        >     "example":{
        >       "admin.example.com":"10.0.1.1",
        >       ...
        >     },
        >     "_":{
        >        "dependencies":{
        >          "example":"staging"
        >        },
        >        "(https?://)?example.com":"http://localhost:3000"
        >     }
        >    },
        >    "environment":"test"
        >  }
      LONGDESC
      def status
        if master_running?
          environment = MultiJson.load(HTTPI.get("http://#{STUBBY_MASTER}:9000/environment.json").body)["environment"]
          activated = MultiJson.load(HTTPI.get("http://#{STUBBY_MASTER}:9000/stubs/activated.json").body)
          puts MultiJson.dump({ "rules" => activated, "environment" => environment }, pretty: true)
        else
          puts MultiJson.dump(status: "error", message: "Stubby currently not running")
        end
      end

      private
      def pidfile
        @pidfile ||= (
          home = File.expand_path("~/.stubby")
          FileUtils.mkdir_p(home) unless File.exists?(home)
          File.join(home, "pid")
        )
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
