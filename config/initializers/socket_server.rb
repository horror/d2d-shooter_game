require 'em-websocket'

EM.next_tick do
  @clients = Hash.new
  @pt
  @players = {"0" => []}
  @maps = Hash.new
  @items = Hash.new
  @tick = 0

  EM::WebSocket.start(:host => '0.0.0.0', :port => 8001) do |ws|
    ws.onopen do
      @clients[ws] = Client.new(@players, @items, @maps)
      @pt ||= EM::PeriodicTimer.new(0.3) do
        if @clients.empty?
          @pt.cancel
          @pt = nil
        end
        @tick += 1
        @clients.each { |ws_handler, client| client.on_message(ws_handler, @players[client.game], @tick) }
      end
    end

    ws.onmessage do |msg|
      #puts "GET: get tick - " + ActiveSupport::JSON.decode(msg)['params']['tick'].to_s + " my tick - " + @tick.to_s
      @clients[ws].process(ActiveSupport::JSON.decode(msg), @tick)
    end

    ws.onclose do
      puts "WebSocket closed"
      @players[@clients[ws].game].delete(@clients[ws].sid)
      @clients.delete(ws)
    end
  end
end