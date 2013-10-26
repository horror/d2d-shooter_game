require 'em-websocket'

EM.next_tick do
  @clients = Set.new
  @pt
  @players = {"0" => []}
  @items = Hash.new
  @tick = 0

  EM::WebSocket.start(:host => '0.0.0.0', :port => 8001) do |ws|

    ws.onopen do
      @clients.add(new_messenger = Client.new(ws))
      new_messenger.start
      @pt ||= EM::PeriodicTimer.new(0.3) do
        if @clients.empty?
          @pt.cancel
          @pt = nil
        end
        @tick += 1
        @clients.each { |client| client.on_message(@tick, @players[client.game]) }
      end
    end

    ws.onmessage do |msg|
      #puts "GET: get tick - " + ActiveSupport::JSON.decode(msg)['params']['tick'].to_s + " my tick - " + @tick.to_s
      @clients.each { |client| client.process(ActiveSupport::JSON.decode(msg), ws, @players, @items, @tick) }
    end

    ws.onclose do
      puts "WebSocket closed"

      @clients.each do |client|
        if client.stop(ws)
          @clients.delete(client) #удалили из масива всех подключений
          @players[client.game].delete(client.sid) #удалили из массива играков
        end
      end
    end
  end
end