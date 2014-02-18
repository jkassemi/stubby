require 'thor'

require 'stubby/registry'
require 'stubby/session'
require 'stubby/extensions/dns'
require 'stubby/extensions/http'

module Stubby
  module CLI
    class Application < Thor
      default_task :status

      # TODO: filesystem watch all config directories for change
      desc "agent", "Starts stubby HTTP and DNS servers"
      def agent
        if permissions? 
          puts "Stubby agent started! CTRL-C to revert system to normal..."
          current_session.run!
        else
          puts "[ERROR] Stubby needs _MORE POWER_ - give it sudo..."
        end
      end

      desc "list", "View status for all installed stubs"
      long_desc <<-LONGDESC
        Alias of `status` without a NAME. This is here to see which I end up
        using most frequently.

        > $ stubby status
        > $ stubby list
      LONGDESC
      def list
        status()
      end

      desc "status NAME", "View status for stub NAME"
      long_desc <<-LONGDESC
        View status for stub NAME. If NAME is not specified, status will list
        all stubs from the config paths. NAME may be a glob, in which case it
        will match any name.

        > $ stubby status
        > _example_
        > _github_ [happy,angry,unavailable]

        > $ stubby mode github happy
        > _github_ *happy

        > $ stubby status github
        > _github_ [*happy,angry,unavailable]
      LONGDESC
      def status(name=nil)
        if name.nil?
          if current_session.system.stubs.empty?
            puts "[INFO] No stubs"
          else
            current_session.system.stubs.each do |k, v|
              status(k) unless k.nil?
            end
          end
        else
          mode = current_session.system.stubs[name].target

          modes = current_session.system.stubs[name].modes.collect { |key, options|
            key == mode ? "*#{key}" : key
          }

          mode = "*#{mode}*" unless mode.to_s.empty?
          modes = modes.empty? ? "" : "[#{modes.join(",")}]"

          puts "_#{name}_ #{modes}"
        end
      end

      desc "mode NAME [MODE]", "View or set mode for NAME"
      long_desc <<-LONGDESC
        Set mode for NAME. If MODE is specified, stubby agent will
        assign that mode to NAME. Otherwise stubby will reset to default
        for the mode (no configurations applied)

        > $ stubby mode github
        > _github_

        > $ stubby mode github happy 
        > _github_ [*happy]

        > $ stubby mode github
        > _github_

      LONGDESC
      def mode(name, mode=nil)
        current_session.system.target(name, mode)
        status(name)
      end 

      desc "local", "Run a local agent based on the Stubfile.json configuration"
      def local(global_mode)
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

        # Install stubs we don't have
        # TODO: versioning syntax?
        (settings["dependencies"] || []).each do |stub, mode|
          install(stub)
        end

        old = current_session.system.session_name

        if old == "_local"
          puts "[ERROR]: Already running a local session?"
          return
        end

        current_session.system.session_remove('_local')
        current_session.system.session_name = '_local'

        (settings["dependencies"] || []).each do |stub, mode|
          mode(stub, mode)
        end

        settings.delete "dependencies"
        current_session.system.stubs["local"] = LocalStub.new(settings)

        current_session.run!(:reload => false)
      ensure
        current_session.system.session_name = old
      end

      desc "search", "Search for a stub"
      def search(name=nil)
        if name.nil?
          puts current_session.registry.index.inspect
        else 
          puts current_session.registry.latest(name).inspect
        end
      end

      desc "install", "Install a stub"
      option(:version)
      option(:source)
      long_desc <<-LONGDESC
        > $ stubby install github
        > _github_

        > $ stubby install http://example.com/mystub.zip
        > mystub [mode1,mode2]

        > $ stubby install github --version=v0.0.1
        > github [mode1,mode2]

        > $ stubby install github --version=v0.0.1 --source=/Users/bob/github.zip
        > github [mode1,mode2]

        # TODO:
        > $ stubby install ./stubby.json
      LONGDESC
      def install(name, override=nil)
        current_session.registry.install(name, override || options)
      end

      desc "update", "Remove stub and then install stub"
      def update(name)
        uninstall(name)
        install(name)
      end

      desc "uninstall", "Remove a stub"
      def uninstall(name)
        current_session.registry.uninstall(name)
      end

      register(CLI::Session, 'session', 'session <command>', 'manages saved sessions')

      private
      def current_session
        # TODO: allow configuration of this
        @session ||= Stubby::Session.new("172.16.123.1").tap do |session|
          session.extensions << Extensions::DNS::Server.new
          session.extensions << Extensions::HTTP::Server.new
          session.extensions << Extensions::Reload.new
        end
      end

      def permissions?
        `whoami`.strip == "root"
      end
    end

  end
end
