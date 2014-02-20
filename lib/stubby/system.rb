require 'stubby/stub'
require 'listen'
require 'fileutils'

module Stubby
  class System
    attr_accessor :session_name

    def initialize
      @path_helper = Stubby::Paths
      @fs_helper = Stubby::FileSystem.new
      stubs
    end

    def root_path=(v)
      @path_helper.root_path = v
    end

    def root_path
      @path_helper.root_path
    end

    def dump
      @fs_helper.write_json @path_helper.session_config_path(session_name), (stubs.inject({}) { |session, k| session[k[0]] = k[1].target; session })
    end

    def stubs
      @stubs ||= @fs_helper.stubs(session_name)
    end

    def reload
      @stubs = nil and stubs
    end

    def target(name, mode=nil)
      if mode.nil? 
        untarget(name)
      else
        stubs[name].target = mode
        dump
      end
    end

    def untarget(name)
      stubs[name].target = nil
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
        @session_name = name and File.write(@path_helper.session_name_path, session_name) and reload
      end
    end

    def session_remove(name)
      @fs_helper.remove_session name
    end

    def current_session_name
      @fs_helper.session_name
    end
  end
end
