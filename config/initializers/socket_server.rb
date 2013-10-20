require 'em-websocket'
require File.dirname(__FILE__) + '/../../lib/messenger.rb'

EM.next_tick do
  EM::WebSocket.start(:host => '0.0.0.0', :port => 8080) do |ws|
    ws.onopen do
      $messenger = Messenger.new(ws)
      $messenger.start
    end

    ws.onmessage do |msg|
      $messenger.send(msg)
    end

    ws.onclose do
      puts "WebSocket closed"
      $messenger.stop
    end
  end
end