# PresenceChannel class.
#
# Uses an EventMachine channel to let handlers interact with the
# Pusher channel. Relay events received from Redis into the
# EM channel. Keeps data on the subscribers to send it to clients.
#

require 'glamazon'
require 'eventmachine'
require 'forwardable'
require 'fiber'

module Slanger
  class PresenceChannel < Channel
    def initialize(attrs)
      super
      # Also subscribe the slanger daemon to a Redis channel used for events concerning subscriptions.
      Slanger.subscribe 'slanger:connection_notification'
    end

    # Send an event received from Redis to the EventMachine channel
    def dispatch(message, channel_id)
      return super unless channel_id =~ /^slanger:/

      # Messages received from the Redis channel slanger:*  carry info on
      # subscriptions. Update our subscribers accordingly.
      update_subscribers message
    end

    def subscribe(msg, callback, &blk)
      publisher, public_subscription_id, channel_data = notify msg

      # Associate the subscription data to the public id in Redis.
      roster.add public_subscription_id, channel_data

      # fuuuuuuuuuccccccck!
      publisher.callback do
        EM.next_tick do
          # The Subscription event has been sent to Redis successfully.
          # Call the provided callback.
          callback.call
          # Add the subscription to our table.
          internal_subscription_table[public_subscription_id] = channel.subscribe &blk
        end
      end

      public_subscription_id
    end

    def notify msg
      channel_data = JSON.parse msg['data']['channel_data']
      id = SecureRandom.uuid

      publisher = connect channel_data, channel_id, id

      return [publisher, id, channel_data]
    end

    def ids
      subscriptions.map { |_,v| v['user_id'] }
    end

    def unsubscribe(id)
      # Unsubcribe from EM::Channel
      if internal_subscription_table[id]
        channel.unsubscribe(internal_subscription_table.delete(id))
      end

      # Remove subscription data from Redis
      roster.remove id

      disconnect channel_id, id
   end

    private

    def roster
      @roster ||= Roster.new channel_id, channel()
    end

    # Send event about the new subscription to the Redis slanger:connection_notification Channel.
    def connect channel_data, channel_id, id
      publish_connection(subscription_id: id,
        online: true,
        channel_data: channel_data,
        channel: channel_id)
    end

    def disconnect channel_id, id
      # Notify all instances
      publish_connection subscription_id: id,
        online: false,
        channel: channel_id

    end

    def publish_connection(payload, retry_count=0)
      Slanger.publish('slanger:connection_notification', payload.to_json).
        tap { |r| r.errback { publish_connection payload, retry_count.succ unless retry_count == 5 } }
    end

    def_delegators :roster, :subscriptions, :subscribers, :update_subscribers

    # This is used map public subscription ids to em channel subscription ids.
    # em channel subscription ids are incremented integers, so they cannot
    # be used as keys in distributed system because they will not be unique
    def internal_subscription_table
      @internal_subscription_table ||= {}
    end
  end
end
