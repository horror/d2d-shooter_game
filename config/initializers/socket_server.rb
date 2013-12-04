require 'em-websocket'

EM.next_tick do
  @clients = Hash.new
  @timer
  @tick = 0
  @games = Hash.new

  def send_clients_response(ws)
    synch = !ValidationHelper.synchron_websocket?
    @clients.each { |ws_handler, client| client.apply_player_changes if synch || client.game_id == @clients[ws].game_id }
    @clients.each { |ws_handler, client| client.apply_projectiles_changes if synch || client.game_id == @clients[ws].game_id }
    @clients.each { |ws_handler, client| client.on_message(@tick) if synch || client.game_id == @clients[ws].game_id }
  end

  EM::WebSocket.start(:host => '0.0.0.0', :port => 8001) do |ws|
    ws.onopen do
      @clients[ws] = Client.new(ws, @games)
      next if ValidationHelper::synchron_websocket?

      @timer ||= EM::PeriodicTimer.new(0.001 * Settings.tick_size) do
        if @clients.empty?
          @timer.cancel
          @timer = nil
        end
        @tick += 1
        send_clients_response(ws)
      end
    end

    ws.onmessage do |msg|
      msg = ActiveSupport::JSON.decode(msg)
      @clients[ws].process(msg, @tick) if msg["action"] != "empty"
      if ValidationHelper::synchron_websocket? && @clients[ws].game
        players = @clients[ws].game.clients
        all_answered = players[msg['params']['sid']].answered = true
        players.each{|sid, player| all_answered &= player.answered}
        next if !all_answered
        @tick += 1
        players.each{|sid, player| players[sid].answered = false}
        send_clients_response(ws)
      end
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
