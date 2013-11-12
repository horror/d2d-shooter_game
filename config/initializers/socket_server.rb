require 'em-websocket'

EM.next_tick do
  @clients = Hash.new
  @pt
  @players = {"0" => []}
  @maps = Hash.new
  @items = Hash.new
  @tick = 0
  @answered_players = {"0" => []}

  EM::WebSocket.start(:host => '0.0.0.0', :port => 8080) do |ws|
    ws.onopen do
      @clients[ws] = Client.new(@players, @items, @maps)
      if !ValidationHelper::synchron_websocket?
        @pt ||= EM::PeriodicTimer.new(0.03) do
          if @clients.empty?
            @pt.cancel
            @pt = nil
          end
          @tick += 1
          @clients.each { |ws_handler, client| client.on_message(ws_handler, @players[client.game], @tick) }
        end
      end
    end

    ws.onmessage do |msg|
      msg = ActiveSupport::JSON.decode(msg)
      @clients[ws].process(msg, @tick) if msg["action"] != "empty"
      if ValidationHelper::synchron_websocket?
        @answered_players[@clients[ws].game] ||= Hash.new
        all_answered = @answered_players[@clients[ws].game][msg['params']['sid']] = true
        @answered_players[@clients[ws].game].each{|sid, val| all_answered &= val}
        if all_answered
          @tick += 1
          @answered_players[@clients[ws].game].each{|sid, val| @answered_players[@clients[ws].game][sid] = false}
          @clients.each { |ws_handler, client| client.on_message(ws_handler, @players[client.game], @tick) if client.game == @clients[ws].game}
        end
      end
    end

    ws.onclose do
      puts "WebSocket closed"
      @players[@clients[ws].game].delete(@clients[ws].sid)
      @answered_players[@clients[ws].game].delete(@clients[ws].sid) if ValidationHelper::synchron_websocket?
      @clients.delete(ws)
    end
  end
end
