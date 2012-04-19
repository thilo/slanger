class Roster
  def initialize channel_id, channel
    @channel_id, @channel = channel_id, channel
  end

  # This is the state of the presence channel across the system. kept in sync
  # with redis pubsub
  def subscriptions
    @subscriptions ||= get || {}
  end

  def subscribers
    Hash[subscriptions.map { |_,v| [v['user_id'], v['user_info']] }]
  end

  def update_subscribers(message)
    if message['online']
      # Don't tell the channel subscriptions a new member has been added if the subscriber data
      # is already present in the subscriptions hash, i.e. multiple browser windows open.
      unless subscriptions.has_value? message['channel_data']
        push payload('pusher_internal:member_added', message['channel_data'])
      end
      subscriptions[message['subscription_id']] = message['channel_data']
    else
      # Don't tell the channel subscriptions the member has been removed if the subscriber data
      # still remains in the subscriptions hash, i.e. multiple browser windows open.
      subscriber = subscriptions.delete message['subscription_id']
      unless subscriptions.has_value? subscriber
        push payload('pusher_internal:member_removed', {
          user_id: subscriber['user_id']
        })
      end
    end
  end

  def payload(event_name, payload = {})
    { channel: channel_id, event: event_name, data: payload }.to_json
  end

  def get
    Fiber.new do
      f = Fiber.current
      Slanger::Redis.hgetall(channel_id).
        callback { |res| f.resume res }
      Fiber.yield
    end.resume
  end

  def add key, value
    Slanger::Redis.hset(channel_id, key, value)
  end

  def remove key
    Slanger::Redis.hdel(channel_id, key)
  end

  private

  attr_reader :channel_id, :channel

  delegate :push, to: :channel
end


