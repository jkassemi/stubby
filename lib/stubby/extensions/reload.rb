require 'listen'

module Extensions
  class Reload
    def run!(session)
      @session = session
      listener.start
      sleep 1 while @listener
    end

    def stop!
      listener.stop rescue nil
      @listener = nil
    end

    private
    def path
      @session.system.path
    end

    def listener
      @listener ||= Listen.to(File.dirname(path)) do |modified, added, removed|
        (modified + added).each do |mpath|
          if File.identical?(path, mpath)
            puts "[INFO] Detected config change, reloading #{path}..."
            @session.system.reload
          end
        end
      end
    end
  end
end
