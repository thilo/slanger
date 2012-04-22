require './spec/spec_helper'
require './spec/integration/shared_context'

describe 'Replacable handler' do
  include_context "shared stuff"

  before(:each) do
    module Slanger; end
    require './lib/slanger/pusher_methods'
    require './lib/slanger/handler'

    class ReplacedHandler < Slanger::Handler
      def authenticate
        super
        send_payload nil, 'pusher:info', { message: "Welcome!" }
      end
    end

    fork_slanger({socket_handler: ReplacedHandler})
  end

  it 'says welcome' do
    messages = messages_for ->(ws,m){m.length < 2}, ->(ws,m){}

    messages.last.should == {"channel"=>nil,
                             "event"=>"pusher:info",
                             "data"=>{"message"=>"Welcome!"}}
  end
end
