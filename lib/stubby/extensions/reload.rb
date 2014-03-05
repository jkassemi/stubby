require 'listen'

module Extensions
  class Reload
    def run!(session, options)
      @options = options
      @session = session
      return if @options[:reload] == false

      listener.start
      sleep 1 while @listener
      puts 'run! done'
    end

    def stop!
      return if @options[:reload] == false
      @listener.stop and @listener = nil if @listener
      puts 'stop! done'
    end

    def restore!

    end

    private
    def root_path
      @session.system.root_path
    end

    def session_config_path
      @session.system.session_config_path
    end

    def listener
      return @listener if @listener

      puts "NEW LISTENER"

      @listener ||= Listen.to(root_path, debug: true) do |modified, added, removed|
        (modified + added).each do |mpath|
          puts "[INFO] Detected change, test identical #{mpath}"
          if File.identical?(session_config_path, mpath)
            puts "[INFO] Detected config change, reloading #{mpath}..."
            @session.system.reload
          end
        end
      end
    end
  end
end
