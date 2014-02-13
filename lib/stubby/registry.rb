require 'oj'
require 'pry'
require 'httpi'

module Stubby
  class RegistryItem
    attr_accessor :name, :version, :source

    def initialize(name, version, source)
      @name = name
      @version = version
      @source = source
    end

    def version
      @version.slice(1, @version.length)
    end

    def install
      # TODO: this should fail gracefully - right now it dies
      # unzipping a non-existent file if the zip doesn't exist, for instance
      puts "source: #{source} - name: #{name}"
      if File.exists? source
        uninstall
        `ln -s #{source} ~/.stubby/#{name}`
      else
        `mkdir -p ~/.stubby`
        download source, "~/.stubby/#{name}.zip"
        `curl #{source} > ~/.stubby/#{name}.zip`
        `unzip ~/.stubby/#{name}.zip`
        `rm ~/.stubby/#{name}.zip`
      end
    end

    def uninstall
      `rm -rf ~/.stubby/#{name}`
    end

    def download(source, destination)
      `curl #{source} #{destination}` 
    end
  end

  class Registry
    def index
      Hash[(remote_index || local_index).collect { |name, versions|
        [name, versions.collect { |version, source|
          RegistryItem.new name, version, source
        }]
      }]
    end

    def versions(name)
      if index[name]
        index[name].sort { |x, y|
          Gem::Version.new(y.version) <=> Gem::Version.new(x.version)
        }
      else
        []
      end
    end

    def version(name, version)
      version = version.gsub("v", "")

      index[name].detect { |stub|
        stub.version == version
      }
    end

    def latest(name)
      versions(name).first
    end

    def install(name, v=nil)
      if name =~ /https?:\/\//
        source = name
        name = File.basename(name).split(".").first
        RegistryItem.new(name, "v1.0.0", source).install
      else
        stub = v.nil? ? latest(name) : version(name, v) 

        if stub
          stub.install
        else
          puts "[ERROR] Cannot find #{name} at #{v}"
        end
      end
    end

    def uninstall(name)
      # TODO: we're not doing a search of the installed stubs'
      # version, but we have a convention of using a ~/.stubby/NAME
      # location, so this shouldn't be a problem for the POC
      if name =~ /https?:\/\//
        name = File.basename(name).split(".").first
      end

      latest(name).uninstall
    end

    private
    def remote_index
      response = HTTPI.get("http://github.com/jkassemi/stubby/index.json")
      Oj.load(response.body) if response.code == 200
    end

    def local_index
      Oj.load(File.read(File.join(File.dirname(__FILE__), "../../index.json")))
    end
  end
end
