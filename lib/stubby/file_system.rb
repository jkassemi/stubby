module Stubby
  class FileSystem
    def initialize
      @path_helper = Stubby::Paths
    end

    def write_json(target, contents)
      File.write target, Oj.dump(contents)
    end

    def session_name
      if File.exists?(@path_helper.session_name_path)
        File.read(@path_helper.session_name_path).strip
      else
        'default'
      end
    end

    def stubs(session = nil)
      session ||= session_name

      stub_context session
    end

    def remove_session(name)
      if File.exists? "#{@path_helper.session_root_path}/#{name}.json"
        `rm #{@path_helper.session_root_path}/#{name}.json`
      else
        puts "[ERROR] Couldn't find session: #{name}"
      end
    end


    private

    # Here we read the current session and update the installed stubs in the session with their current target
    def stub_context(session)
      return installed_stubs unless File.exists? @path_helper.session_config_path(session)

      session_config = File.read(@path_helper.session_config_path(session))
      installed = installed_stubs

      Oj.load(session_config).each do |k, v|
        fatal_oopsie("#{k} isn't installed!") unless installed[k]
        installed[k].target = v
      end

      installed
    end

    # get the list of installed stubs
    def installed_stubs
      installed_glob.inject({}) do |stubs, stub|
        stubs[stub.split("/")[-2]] = Stub.new stub
        stubs
      end
    end

    def installed_glob
      Dir.glob "#{@path_helper.root_path}/**/stubby.json"
    end

    def fatal_oopsie(message)
      puts "[ERROR] #{message}"

      exit
    end
  end
end