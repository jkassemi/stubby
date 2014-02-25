require 'mail_catcher'

module Extensions
  module SMTP
    class Server
      def run!(session, options)
        HTTPI.post("http://#{STUBBY_MASTER}:9000/stubs/transient/activate.json",
          options: MultiJson.dump(smtp_stub), key: "_smtp")
                          
        @process = Process.fork {
          MailCatcher.run! smtp_ip: STUBBY_MASTER,
            smtp_port: 25,
            http_ip: STUBBY_MASTER,
            http_port: 9001
        }

        trap("INT"){
          stop!
        }

        sleep
      end

      def smtp_stub
        {
          "dns-mx://.*" => "dns-mx://#{STUBBY_MASTER}",
          "(http:\/\/)?outbox.stubby.dev" => "http://#{STUBBY_MASTER}:9001"
        }
      end

      def stop!
        Process.kill("TERM", @process)
        exit
      end
    end
  end
end
