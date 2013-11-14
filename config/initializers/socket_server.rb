require 'em-websocket'

EM.next_tick do
  @clients = Hash.new
  @timer
  @tick = 0
  @games = Hash.new

  EM::WebSocket.start(:host => '0.0.0.0', :port => 8001) do |ws|
    ws.onopen do
      @clients[ws] = Client.new(ws, @games)

      if !ValidationHelper::synchron_websocket?
        @timer ||= EM::PeriodicTimer.new(0.03) do
          if @clients.empty?
            @timer.cancel
            @timer = nil
          end
          @tick += 1
          @clients.each { |ws_handler, client| client.on_message(@tick) }
        end
      end
    end

    ws.onmessage do |msg|
      msg = ActiveSupport::JSON.decode(msg)
      @clients[ws].process(msg, @tick) if msg["action"] != "empty"

      if ValidationHelper::synchron_websocket? && @clients[ws].game
        answered_players = @clients[ws].game.answered_players
        all_answered = answered_players[msg['params']['sid']] = true
        answered_players.each{|sid, val| all_answered &= val}
        if all_answered
          @tick += 1
          answered_players.each{|sid, val| answered_players[sid] = false}
          @clients.each {|ws_handler, client| client.on_message(@tick) if client.game_id == @clients[ws].game_id}
        end
      end
    end

    ws.onclose do
      puts "WebSocket closed"
      if @clients[ws].game
        @clients[ws].game.answered_players.delete(@clients[ws].sid) if ValidationHelper::synchron_websocket?
        @clients[ws].game.players.delete(@clients[ws].sid)
      end
      @clients.delete(ws)
    end
  end
end
