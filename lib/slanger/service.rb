require 'puma'
require 'rack'

module Slanger
  module Service
    def run
      Slanger::Config[:require].each { |f| require f }
      Slanger::WebSocketServer.run
      Rack::Handler.get(:puma).run Slanger::ApiServer, Host: Slanger::Config.api_host, Port: Slanger::Config.api_port, quiet: false, enviroment: 'environment'
    end

    def stop
      EM.stop if EM.reactor_running?
    end

    extend self
    Signal.trap('HUP') { Slanger::Service.stop }
  end
end
