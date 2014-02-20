module Stubby
  class Paths
    class << self
      attr_accessor :root_path

      def root_path
        @root_path || File.expand_path("~/.stubby")
      end

      # TODO: Cache this somehow.  It feels weird to mkdir everytime we ask for this.
      def session_root_path
        FileUtils.mkdir_p("#{root_path}/sessions")[0]
      end

      def session_config_path(session_name)
        File.expand_path "#{session_root_path}/#{session_name}.json"
      end

      def session_name_path
        "#{session_root_path}/current"
      end
    end
  end
end