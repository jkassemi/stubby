require 'pry'
require 'httpi'

module Stubby
  class RegistryItem
    attr_accessor :name, :source

    def initialize(source)
      @source = URI.parse(source)
      @name = @source.path
    end

    def install
      `mkdir -p #{path}`
      `cd #{path} && git clone #{@source} .`
    end

    def path
      "~/.stubby/#{@source.path}"
    end

    def uninstall
      `rm -rf ~/.stubby/#{@source.path}`
    end

    def installed?
      File.exists? path
    end

    def config
      "~/.stubby/#{@source.path}/stubby.json"
    end

    def stub(target=nil)
      install unless installed?
      Stub.new(config, target)
    end
  end

  class Registry
    def install(source)
      RegistryItem.new(source).install
    end

    def uninstall(source)
      RegistryItem.new(source).uninstall
    end
  end
end
