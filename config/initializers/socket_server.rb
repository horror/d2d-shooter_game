require 'em-websocket'
require File.dirname(__FILE__) + '/../../lib/messenger.rb'

EM.next_tick do
  @messengers = Set.new
  @connections = 0
  @pt
  EM::WebSocket.start(:host => '0.0.0.0', :port => 8080) do |ws|



    ws.onopen do
      @connections += 1
      @messengers.add(new_messenger = Messenger.new(ws))
      new_messenger.start
      @pt ||= EM::PeriodicTimer.new(30.0 / 1000.0) do
        if @messengers.empty?
          @pt.cancel
          @pt = nil
        end

        @messengers.each { |messenger| messenger.send("ok") }
      end
    end

    ws.onmessage do |msg|
      @messengers.each { |messenger| messenger.process(ActiveSupport::JSON.decode(msg), ws) }
    end

    ws.onclose do
      puts "WebSocket closed"

      @messengers.each do |messenger|
        @messengers.delete(messenger) if messenger.stop(ws)
      end
    end
  end
end