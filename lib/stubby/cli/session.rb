module Stubby
  module CLI
    class Session < Thor
      desc "remove", "Remove a saved session"
      long_desc <<-LONGDESC
        > $ stubby session remove test1
      LONGDESC
      def remove(name)
        system.session_name = name
        system.session_remove(name)
      end

      desc "name", "Return current session name"
      long_desc <<-LONGDESC
        > $ stubby session name
        > default

        > $ stubby session test1
        > test1

        > $ stubby session name
        > test1
      LONGDESC
      def name
        puts system.session_name
      end

      desc "set", "Set or unset session"
      long_desc <<-LONGDESC
        > $ stubby mode github happy
        > $ stubby mode facebook happy
        > $ stubby session set test1

        > $ stubby status
        > _github_ [*happy,angry,unavailable]
        > _facebook_ [*happy,angry,unavailable]

        > $ stubby session set

        > $ stubby status
        > _github_ [happy,angry,unavailable]
        > _facebook_ [happy,angry,unavailable]

        > $ stubby session set test1
        > _github_ [*happy,angry,unavailable]
        > _facebook_ [*happy,angry,unavailable]

        > $ stubby session remove test1
      LONGDESC
      def set(name)
        system.session_name = name
        puts name
      end

      private
      def system
        @system ||= System.new
      end
    end
  end
end
