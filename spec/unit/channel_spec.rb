require 'spec/spec_helper'
require 'slanger'

describe 'Slanger::Webhook' do
  let(:channel) { Slanger::Channel.create channel_id: 'test' }

  before(:all) do
    EM::Hiredis.stubs(:connect).returns stub_everything('redis')
  end

  after(:all) do
    EM::Hiredis.unstub(:connect)
  end

  describe '#unsubscribe' do
    it 'increments channel subscribers on Redis' do
      Slanger::Redis.expects(:hincrby).
        with('channel_subscriber_count', channel.channel_id, -1).
        returns 1
      channel.unsubscribe 1
    end
  end

  describe '#subscribe' do
    it 'decrements channel subscribers on Redis' do
      Slanger::Redis.expects(:hincrby).
        with('channel_subscriber_count', channel.channel_id, 1)
      channel.subscribe { |m| nil }
    end
  end

end

