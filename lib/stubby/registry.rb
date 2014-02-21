require 'oj'
require 'pry'
require 'httpi'

module Stubby
  class RegistryItem
    attr_accessor :name, :version, :source, :location

    def initialize(name, version, source)
      @name = name
      @version = version
      @source = source
      @location = "~/.stubby/#{name}"
    end

    def version
      @version.slice(1, @version.length)
    end

    def install
      if File.exists? source
        uninstall
        `ln -s #{source} ~/.stubby/#{name}`
      else
        `mkdir -p ~/.stubby`
        download source, "~/.stubby/#{name}.zip"
        `curl #{source} > ~/.stubby/#{name}.zip`
        `unzip -d ~/.stubby/ #{source}`
        `rm ~/.stubby/#{name}.zip`
      end
    end

    def uninstall
      `rm -rf ~/.stubby/#{name}`
    end

    def installed?
      File.exists? @location
    end

    def download(source, destination)
      `curl #{source} #{destination}` 
    end

    def config
      File.join("~", ".stubby", name)
    end

    def stub(target=nil)
      install unless installed?
      Stub.new(config, target)
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

    def install(name, opts={})
      source = opts[:source]
      v = opts[:version]

      if name =~ /https?:\/\//
        source = name
        name = File.basename(name).split(".").first
        RegistryItem.new(name, "v1.0.0", source).install
      else
        stub = v.nil? ? latest(name) : version(name, v) 

        if stub
          stub.install
        elsif source
          add_new_source(name, source, v)
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
      Oj.load(File.read(File.expand_path(File.join('~', '.stubby', "index.json"))))
    rescue 
      {}
    end

    def write_local_index(&block)
      File.open File.expand_path(File.join('~', '.stubby', "index.json")), "w", &block
    end

    def add_new_source(name, source, v=nil)
      version = v.nil? ? 'v0.0.1' : v

      item = RegistryItem.new name, version, source
      item.install

      current_index = local_index

      write_local_index do |index|
        index.puts Oj.dump(local_index.merge({item.name => {item.version => item.location}}))
      end
    end
  end
end
