require 'em-websocket'
require File.dirname(__FILE__) + '/../../lib/messenger.rb'

EM.next_tick do
  @messengers = Set.new
  @pt
  @players = {"0" => []}
  @items = Hash.new
  @tick = 0

  EM::WebSocket.start(:host => '0.0.0.0', :port => 8001) do |ws|

    ws.onopen do
      @messengers.add(new_messenger = Messenger.new(ws))
      new_messenger.start
      @pt ||= EM::PeriodicTimer.new(0.3) do
        if @messengers.empty?
          @pt.cancel
          @pt = nil
        end
        @tick += 1
        @messengers.each { |messenger| messenger.on_message(@tick, @players[messenger.game]) }
      end
    end

    ws.onmessage do |msg|
      #puts "GET: get tick - " + ActiveSupport::JSON.decode(msg)['params']['tick'].to_s + " my tick - " + @tick.to_s
      @messengers.each { |messenger| messenger.process(ActiveSupport::JSON.decode(msg), ws, @players, @items, @tick) }
    end

    ws.onclose do
      puts "WebSocket closed"

      @messengers.each do |messenger|
        if messenger.stop(ws)
          @messengers.delete(messenger) #удалили из масива всех подключений
          @players[messenger.game].delete(messenger.sid) #удалили из массива играков
        end
      end
    end
  end
end