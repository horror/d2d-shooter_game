require 'em-websocket'
require File.dirname(__FILE__) + '/../../lib/messenger.rb'

EM.next_tick do
  @messengers = Set.new
  @connections = 0
  @pt
  @players = {"0" => []}
  @items = Hash.new

  EM::WebSocket.start(:host => '0.0.0.0', :port => 8080) do |ws|

    ws.onopen do
      @connections += 1
      @messengers.add(new_messenger = Messenger.new(ws))
      new_messenger.start
      @pt ||= EM::PeriodicTimer.new(1) do
        if @messengers.empty?
          @pt.cancel
          @pt = nil
        end

        @messengers.each { |messenger| messenger.on_message(@players[messenger.game]) }
      end
    end

    ws.onmessage do |msg|
      @messengers.each { |messenger| messenger.process(ActiveSupport::JSON.decode(msg), ws, @players, @items) }
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