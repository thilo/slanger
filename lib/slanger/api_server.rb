# encoding: utf-8
require 'sinatra/base'
require 'signature'
require 'json'
require 'active_support/core_ext/hash'
require 'eventmachine'
require 'em-hiredis'
require 'rack'
require 'fiber'
require 'rack/fiber_pool'

module Slanger
  class ApiServer < Sinatra::Base
    use Rack::FiberPool
    set :raise_errors, lambda { false }
    set :show_exceptions, false

    # Respond with HTTP 401 Unauthorized if request cannot be authenticated.
    error(Signature::AuthenticationError) { |c| halt 401, "401 UNAUTHORIZED\n" }

    post '/apps/:app_id/channels/:channel_id/events' do
      authenticate_request params

      f = Fiber.current

      publish(params[:channel_id]) do |r|
        r.callback { f.resume [202, {}, "202 ACCEPTED\n"] }
        r.errback  { f.resume [500, {}, "500 INTERNAL SERVER ERROR\n"] }
      end

      Fiber.yield
    end

    def publish channel_id
      Slanger.publish(channel_id, payload).tap do |r|
        yield r
      end
    end

    # Raises Signature::AuthenticationError if request does not authenticate
    def authenticate_request params
      Signature::Request.new('POST', env['PATH_INFO'], only_pusher(params) ).
        authenticate { |key| Signature::Token.new key, Slanger::Config.secret }
    end

    # exclude params included by sinatra but not sent by Pusher
    def only_pusher params
      params.except('channel_id', 'app_id')
    end

    def payload
      payload = {
        event:     params['name'],
        data:      request.body.read.tap { |s| s.force_encoding('utf-8') },
        channel:   params[:channel_id],
        socket_id: params[:socket_id]
      }
      Hash[payload.reject { |_,v| v.nil? }].to_json
    end
  end
end

