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

  def self.inc_tick
    @tick += 1
  end

  def self.send_clients_response(ws)
    clients.each { |ws_handler, client| client.apply_changes if !synchron? || client.game_id == clients[ws].game_id }
    @games.each { |ws_handler, game| game.apply_changes if !synchron? || game.id == clients[ws].game_id }
    clients.each { |ws_handler, client| client.on_message(@tick) if !synchron? || client.game_id == clients[ws].game_id }
  end

  def self.on_open(ws)
    clients[ws] = Client.new(ws, @games)
    puts "WS Open"
  end

  def self.on_message(ws, msg)
    msg = ActiveSupport::JSON.decode(msg)
    msg['params']['sid'] ||= clients[ws].sid
    clients[ws].process(msg, @tick)
    if synchron? && clients[ws].game
      players = clients[ws].game.clients
      return if  !players[msg['params']['sid']]
      all_answered = true
      players.each{|sid, player| all_answered &= player.answered if player}
      return if !all_answered
      @tick += 1
      players.each{|sid, player| players[sid].answered = false if players[sid]}
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
  EM.set_timer_quantum(5)
  @start = @next = Time.now.to_f
  @interval = Settings.tick_size / 1000
  EM.add_periodic_timer(@interval) do
    if Time.now.to_f >= @next
      @next = WS.inc_tick * @interval + @start
      WS.send_clients_response(nil)
    end
  end

  EM::WebSocket.start(:host => '0.0.0.0', :port => 8001) do |ws|
    ws.onopen { WS.on_open(ws) }
    ws.onmessage { |msg| WS.on_message(ws, msg) }
    ws.onclose { WS.on_close(ws) }
  end
end