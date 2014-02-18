require 'oj'
require 'stubby/system'

require("fiddle")

def set_process_name(name)
    RUBY_PLATFORM.index("linux") or return
    Fiddle::Function.new(
        DL::Handle["prctl"], [
            Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP,
            Fiddle::TYPE_LONG, Fiddle::TYPE_LONG,
            Fiddle::TYPE_LONG
        ], Fiddle::TYPE_INT
    ).call(15, name, 0, 0, 0)
end

module Stubby
  class Session
    attr_accessor :extensions, :host

    def initialize(host)
      @host = host
      @extensions = []
    end

    def run!(options={})
      begin
        assume_network_interface
        run_extensions(options)
      ensure
        unassume_network_interface
      end
    end

    def target(name, target=nil)
      system.target(name, target)
    end

    def search(trigger)
      system.stubs.each do |name, stub|
        # TODO: In parallel, this'll get slow
        res = stub.search(trigger)
        return res if res
      end

      nil
    end

    def registry
      @registry ||= Stubby::Registry.new
    end

    def system
      @system ||= Stubby::System.new
    end

    private
    def stop_extensions(signal)
      puts "Shutting down..."

      @running.each do |process|
        Process.kill(signal, process)
      end

      puts "Bye."
    end

    def run_extensions(options)
      @running = @extensions.collect { |plugin|
        Process.fork do
          $0 = "stubby: #{plugin.class.name}"
          plugin.run!(self, options)
        end
      }

      Thread.new {
        sleep 2
        puts "CTRL-C to exit stubby"
      }

      trap("INT") { 
        stop_extensions("QUIT") and exit 
      }
      
      @running.each do |process|
        Process.waitpid(process)
      end
    end

    def assume_network_interface
      `ifconfig lo0 alias #{host}`
    end

    def unassume_network_interface
      `ifconfig lo0 -alias #{host}`
    end
  end
end
