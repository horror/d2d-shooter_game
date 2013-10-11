require 'em-websocket'

EM.next_tick do
  EM::WebSocket.start(:host => "localhost", :port => 8080) do |ws|
    ws.onopen    { ws.send "Hello Client!"}
    ws.onmessage { |msg| ws.send "Pong: #{msg}" }
    ws.onclose   { puts "WebSocket closed" }
  end
end