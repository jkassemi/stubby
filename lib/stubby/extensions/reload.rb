require 'listen'

module Extensions
  class Reload
    def run!(session)
      @session = session
      listener.start
      sleep 1 while @listener
    end

    def stop!
      listener.stop
    end

    private
    def root_path
      @session.system.root_path
    end

    def session_config_path
      @session.system.session_config_path
    end

    def listener
      @listener ||= Listen.to(root_path) do |modified, added, removed|
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
