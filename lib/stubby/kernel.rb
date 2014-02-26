$tracked = {}

module Kernel
  alias _trap trap

  def trap(*args, &block)
    #puts "kernel::trap: #{args.inspect}\n---------------\n #{caller.join("\n")}\n\n"

    if args.last.is_a? Hash
      options = args.pop
    else
      options = {}
    end

    if options[:important]
      track(args.first, _trap(*args, &block))
    else
      if tracked?(args.first)
        puts "kernel::trap: #{args.inspect} ignoring"
      else
        _trap(*args, &block) 
      end
    end
  end

  private
  def track(signal, child_pid)
    (($tracked ||= {})[Process.pid] ||= {})[signal] = child_pid
  end

  def tracked?(signal)
    !!($tracked[Process.pid][signal])
  rescue
    false
  end
end
