module Stubby
  class Stub
    attr_accessor :target, :path, :modes

    # TODO: target is mode, rename
    def initialize(path, target=nil)
      self.path = path
      self.target = target
    end

    def modes
      @modes ||= MultiJson.load(File.read(path))
    rescue => e
      if File.exists?(path)
        puts "[INFO] Problem parsing #{path}"
        raise e
      end
    end

    def path=(v)
      unless v and File.exists?(File.expand_path(v))
        puts "'#{v}' not found. Use --config to specify a different config file"
        exit
      end

      @path = File.expand_path(v)
    end

    def target=(environment)
      @environment = environment 
      @options = nil
      options
    end

    def options
      @options ||= expand(modes[@environment] || {})
    end

    def search(trigger)
      options.each do |rule, instruction|
        if match=Regexp.new(rule, Regexp::EXTENDED | Regexp::IGNORECASE).match(trigger)
          instruction = instruction.dup

          match.to_a.each_with_index.map do |v, i|
            instruction.gsub!("$#{i}", v)
          end

          return instruction
        end
      end

      return nil
    end

    private
    def expand(options)
      Stubby::Api.expand_rules(options) 
    end
  end

  class TransientStub < Stub
    def initialize(options)
      @options = expand(options)
    end

    def modes 
      {}
    end

    def options
      @options
    end 
  end
end
