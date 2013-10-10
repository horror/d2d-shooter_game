require "spec_helper"
require 'eventmachine'

describe 'Socket server' do

  it 'simple test' do
    EM.run {
      client = Faye::Client.new('http://localhost:3000/faye')
      publication = client.publish('/foo', 'text' => 'Hello world')
      EM.stop_event_loop
    }
    pending "socket test"
  end
end