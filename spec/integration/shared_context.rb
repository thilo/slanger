shared_context "shared stuff" do
  let(:errback) { Proc.new { fail 'cannot connect to slanger. your box might be too slow. try increasing sleep value in the before block' } }
  let(:user_id)        {'0f177369a3b71275d25ab1b44db9f95f'}
  let(:second_user_id) {'37960509766262569d504f02a0ee986d'}
  let(:app_key)        {'765ec374ae0a69f4ce44'}
  let(:api_port)       {'4567'}

  after(:each) do
    # Ensure Slanger is properly stopped. No orphaned processes allowed!
    Process.kill 'SIGKILL', @server_pid
    Process.wait @server_pid
  end

  before :all do
    Pusher.tap do |p|
      p.app_id = 'your-pusher-app-id'
      p.host   = '0.0.0.0'
      p.port   = api_port.to_i
      p.key    = app_key
      p.secret = 'your-pusher-secret'
    end
  end
end
