require 'stubby/stub'
require 'listen'
require 'pry'

module Stubby
  class System
    def initialize
      stubs and listen
    end

    def dump
      File.write(path, Oj.dump(Hash[@stubs.collect { |k,v|
        [k, v.target] 
      }]))
    end

    def stubs
      @stubs ||= installed_stubs.merge(loaded_stubs)
    end

    def target(name, mode=nil)
      if mode.nil? 
        untarget(name)
      else
        @stubs[name].target = mode
        dump
      end
    end

    def untarget(name)
      @stubs[name].target = nil
      dump
    end

    def path
      File.expand_path("~/.stubby/system.json")
    end

    def search_paths
      [File.expand_path("~/.stubby")]
    end

    private
    def listen
      listener = Listen.to(File.dirname(path)) do |modified, added, removed|
        (modified + added).each do |mpath|
          if File.identical?(path, mpath)
            puts "[INFO] Detected config change, reloading #{path}..."
            @stubs = nil and stubs
          end
        end
      end

      listener.start
    end

    def installed_stubs
      Hash[search_paths.collect { |search_path|
        Dir[search_path + "/**"]
      }.flatten.collect { |path|
        next unless File.exists?(path + "/stubby.json")
        [File.basename(path), Stub.new(path + "/stubby.json")]
      }.compact]
    end

    def loaded_stubs
      is = installed_stubs

      if File.exists?(path)
        Hash[Oj.load(File.read(path)).collect { |k, v|
          is[k].target = v
          [k, is[k]]
        }]
      else
        @stubs = {}
      end
    end
  end
end
