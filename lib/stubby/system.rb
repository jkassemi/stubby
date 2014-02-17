require 'stubby/stub'
require 'listen'
require 'fileutils'

module Stubby
  class System
    attr_accessor :session_name,
      :root_path

    def initialize
      stubs
    end

    def dump
      File.write(session_config_path, Oj.dump(Hash[@stubs.collect { |k,v|
        [k, v.target] 
      }]))
    end

    def stubs
      @stubs ||= installed_stubs.merge(loaded_stubs)
    end

    def reload
      @stubs = nil and stubs
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

    def session_name
      @session_name || current_session_name
    end

    def session_name=(name)
      if name.to_s.empty?
        name = "default"
      end

      if current_session_name != name
        @session_name = name and File.write(session_name_path, session_name) and reload
      end
    end

    def session_remove(name)
      `rm #{session_root_path}/#{name}.json`
    end

    def root_path
      @root_path || File.expand_path("~/.stubby")
    end

    def session_root_path
      "#{root_path}/sessions".tap do |path|
        FileUtils.mkdir_p(path) unless File.exists?(path)
      end
    end

    # Stores the session values itself
    def session_config_path
      File.expand_path("#{session_root_path}/#{session_name}.json")
    end

    # Stores the current session name
    def session_name_path
      "#{session_root_path}/current"  
    end

    def current_session_name
      if File.exists?(session_name_path)
        File.read(session_name_path).strip
      else
        "default"
      end
    end

    private
    def installed_stubs
      # TODO: clean me
      Hash[Dir[root_path + "/**"].collect { |path|
        next unless File.exists?(path + "/stubby.json")
        [File.basename(path), Stub.new(path + "/stubby.json")]
      }.compact]
    end

    def loaded_stubs
      # TODO: clean me
      is = installed_stubs

      if File.exists?(session_config_path)
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
