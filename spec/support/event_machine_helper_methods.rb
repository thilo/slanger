module EventMachineHelperMethods
  # Our integration tests MUST block the main thread because
  # we want to wait for i/o to finish.
  def fork_slanger config = {}
    config = default_config.merge config
    @server_pid = EM.fork_reactor do
      require_relative '../../slanger.rb'
      Thin::Logging.silent = true

      Slanger::Config.load config
      Slanger::Service.run
    end
    # Give Slanger a chance to start
    sleep 0.6
  end

  def default_config
    {  host:           '0.0.0.0',
       websocket_port: '8080',
       api_port:       api_port,
       app_key:        app_key,
       secret:         'your-pusher-secret'
    }
  end

  def app_key; '765ec374ae0a69f4ce44'; end
  def api_port;'4567'                ; end

  def new_websocket
    uri = "ws://0.0.0.0:8080/app/#{Pusher.key}?client=js&version=1.8.5"

    EM::HttpRequest.new(uri).get(:timeout => 0).tap do |ws|
      ws.errback &errback
    end
  end

  def em_stream
    messages = []

    em_thread do
      websocket = new_websocket

      stream(websocket, messages) do |message|
        yield websocket, messages
      end
    end

    return messages
  end

  def em_thread
    Thread.new do
      EM.run do
        yield
      end
    end.join
  end

  def stream websocket, messages
    websocket.stream do |message|
      messages << JSON.parse(message)

      yield message
    end
  end

  def messages_for condition, if_true
    em_stream do |websocket, messages|
      if condition.call(websocket,messages)
        if_true.call(websocket, messages)
        yield websocket, messages if block_given?
      else
        EM.stop
      end
    end
  end

  def auth_from options
    id = options[:message]['data']['socket_id']
    name = options[:name]
    user_id = options[:user_id]
    Pusher['presence-channel'].authenticate(id, {user_id: user_id, user_info: {name: name}})
  end

  def send_subscribe options
    auth = auth_from options
    options[:user].send({event: 'pusher:subscribe',
                         data: {channel: 'presence-channel'}.merge(auth)}.to_json)
  end

  def private_channel websocket, message
    auth = Pusher['private-channel'].authenticate(message['data']['socket_id'])[:auth]
    websocket.send({ event: 'pusher:subscribe',
                     data: { channel: 'private-channel',
                             auth: auth } }.to_json)

  end
end
