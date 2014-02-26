require 'timeout'

module Process extend self
  def running?(pid)
    !!(kill(0, pid))
  rescue
    false
  end

  def shutdown(pid, timeout=10, sig1="TERM", sig2="KILL")
    puts "Shutting down: #{pid}"

    kill(sig1, pid)

    Timeout::timeout(timeout) do
      sleep 1 and puts "." while running?(pid)
    end 
  rescue Timeout::Error
    kill(sig2, pid)
  end

end
