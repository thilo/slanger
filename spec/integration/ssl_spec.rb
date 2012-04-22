require 'bundler/setup'

require 'eventmachine'
require 'thin'
require './spec/spec_helper'
require 'openssl'
require 'socket'

describe 'SSL' do
  before(:each) do
    config = { tls_options: {
      cert_chain_file:  'spec/server.crt',
      private_key_file: 'spec/server.key'
    }}

    fork_slanger config
  end

  describe 'Slanger when configured to use SSL' do
    it 'encrypts the connection' do
      socket                 = TCPSocket.new('0.0.0.0', 8080)
      expected_cert          = OpenSSL::X509::Certificate.new(File.open('spec/server.crt'))
      ssl_socket             = OpenSSL::SSL::SSLSocket.new(socket)
      ssl_socket.connect
      ssl_socket.peer_cert.to_s.should == expected_cert.to_s
    end
  end
end
