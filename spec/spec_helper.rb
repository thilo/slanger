require 'pusher'
require 'eventmachine'
require './spec/support/event_machine_helper_methods'
require './spec/support/have_attributes'

require 'bundler/setup'

require 'active_support/json'
require 'active_support/core_ext/hash'
require 'eventmachine'
require 'em-http-request'
require 'pusher'
require 'thin'
require 'pry'

RSpec.configure do |config|
  config.include EventMachineHelperMethods
end

module Kernel
  def debugger
    binding.pry
  end
end
