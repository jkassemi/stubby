require 'pry'

module Stubby
  class Stub
    attr_accessor :target, :path, :modes

    # TODO: target is mode, rename
    def initialize(path, target=nil)
      self.path = path
      self.target = target
    end

    def modes
      @modes ||= Oj.load(File.read(path))
    rescue
      {}
    end

    def path=(v)
      unless v and File.exists?(File.expand_path(v))
        puts "'#{v}' not found. Use --config to specify a different config file"
        exit
      end

      @path = File.expand_path(v)
    end

    def options
      modes[target] || {}
    end

    def search(trigger)
      options.each do |rule, instruction|
        if Regexp.new(rule, Regexp::EXTENDED | Regexp::IGNORECASE).match(trigger)
          return instruction
        end
      end

      return nil
    end
  end

  class TransientStub < Stub
    def initialize(options)
      @options = options
    end

    def modes 
      {}
    end

    def options
      @options
    end 
  end
end
