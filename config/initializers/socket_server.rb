require 'em-websocket'

module WS

  @synchron = false
  @clients = Hash.new
  @timer
  @tick = 0
  @games = Hash.new

  def self.switch_on_synchron_mode(val)
    @synchron = val
  end

  def self.synchron?
    @synchron
  end

  def self.clients
    @clients
  end

  def self.games
    @games
  end

  def self.send_clients_response(ws)
    clients.each { |ws_handler, client| client.apply_changes if !synchron? || client.game_id == clients[ws].game_id }
    @games.each { |ws_handler, game| game.apply_changes if !synchron? || game.id == clients[ws].game_id }
    clients.each { |ws_handler, client| client.on_message(@tick) if !synchron? || client.game_id == clients[ws].game_id }
  end

  def self.on_open(ws)
    clients[ws] = Client.new(ws, @games)
    puts "WS Open"
    return if synchron?
    @timer ||= EM::PeriodicTimer.new(0.001 * Settings.tick_size) do
      if clients.empty?
        @timer.cancel
        @timer = nil
      end
      @tick += 1
      send_clients_response(ws)
    end
  end

  def self.on_message(ws, msg)
    msg = ActiveSupport::JSON.decode(msg)
    puts "Client MSG: #{msg}"
    msg['params']['sid'] ||= clients[ws].sid
    clients[ws].process(msg, @tick) if msg["action"] != "empty"
    if synchron? && clients[ws].game
      players = clients[ws].game.clients
      all_answered = players[msg['params']['sid']].answered = true
      players.each{|sid, player| all_answered &= player.answered}
      return if !all_answered
      @tick += 1
      players.each{|sid, player| players[sid].answered = false}
      send_clients_response(ws)
    end
  end

  def self.on_close(ws)
    puts "WebSocket closed"
    if clients[ws].game
      clients[ws].game.save_stats
      #clients[ws].game.clients.delete(clients[ws].sid)
    end
    clients.delete(ws)
  end

end

EM.next_tick do
  EM::WebSocket.start(:host => '0.0.0.0', :port => 8001) do |ws|
    ws.onopen { WS.on_open(ws) }

    ws.onmessage { |msg| WS.on_message(ws, msg) }

    ws.onclose { WS.on_close(ws) }
  end
end
