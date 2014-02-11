require 'oj'
require 'stubby/system'

module Stubby
  class Session
    attr_accessor :extensions, :host

    def initialize(host)
      @host = host
      @extensions = []
    end

    def run!
      begin
        assume_network_interface
        run_extensions
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
    def stop_extensions
      @extensions_stopped ||= (
        @extensions.each do |plugin|
          plugin.stop!
        end
      )
    end

    def run_extensions
      trap("INT") { stop_extensions }
      Thread.abort_on_exception = true

      @extensions.collect { |plugin|
        Thread.new { 
          plugin.run!(self) 
        }
      }.map(&:join)
    ensure
      stop_extensions
    end

    def assume_network_interface
      `ifconfig lo0 alias #{host}`
    end

    def unassume_network_interface
      `ifconfig lo0 -alias #{host}`
    end
  end
end
