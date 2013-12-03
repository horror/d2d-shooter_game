require 'em-websocket'

EM.next_tick do
  @clients = Hash.new
  @timer
  @tick = 0
  @games = Hash.new

  EM::WebSocket.start(:host => '0.0.0.0', :port => 8001) do |ws|
    ws.onopen do
      @clients[ws] = Client.new(ws, @games)

      @timer ||= EM::PeriodicTimer.new(0.001 * Settings.tick_size) do
        if @clients.empty?
          @timer.cancel
          @timer = nil
        end
        @tick += 1
        @clients.each { |ws_handler, client| client.apply_player_changes }
        @clients.each { |ws_handler, client| client.apply_projectiles_changes }
        @clients.each { |ws_handler, client| client.on_message(@tick) }
      end
    end

    ws.onmessage do |msg|
      msg = ActiveSupport::JSON.decode(msg)
      @clients[ws].process(msg, @tick) if msg["action"] != "empty"
    end

    ws.onclose do
      puts "WebSocket closed"
      if @clients[ws].game
        @clients[ws].game.clients.delete(@clients[ws].sid)
      end
      @clients.delete(ws)
    end
  end
end
