require 'mail_catcher'

module Stubby
  module Extensions
    module SMTP
      class Server
        def run!(session, options)
          @process = Process.fork {
            $0 = "stubby: [extension worker sub] Stubby::Extensions::SMTP::Server"

            sleep 2

            HTTPI.post("http://#{STUBBY_MASTER}:9000/stubs/transient/activate.json",
              options: MultiJson.dump(smtp_stub), key: "_smtp")
            
            MailCatcher.run! smtp_ip: STUBBY_MASTER,
              smtp_port: 25,
              http_ip: STUBBY_MASTER,
              http_port: 9001,
              daemon: false
          }

          trap("INT", important: true){
            stop!
          }

          sleep
        end

        def smtp_stub
          {
            "dns://outbox.stubby.dev/a" => "dns-a://#{STUBBY_MASTER}",
            "http://outbox.stubby.dev" => "http://#{STUBBY_MASTER}:9001"
          }
        end

        def expand_rule(trigger, instruction)
          {
            "#{trigger.gsub("smtp://", "dns://")}/mx" => "dns-mx://#{STUBBY_MASTER}/?priority=10"
          }
        end

        def stop!
          Process.shutdown(@process)
        end

        def restore!
          # nil 
        end
      end
    end
  end
end
