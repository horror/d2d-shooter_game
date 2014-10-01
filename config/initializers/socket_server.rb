
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

require 'eventmachine'
require 'rack'
require 'thin'

require 'faye/websocket'

App = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env)

    ws.on :open do |event|
      WS.on_open(ws)
    end

    ws.on :message do |event|
      WS.on_message(ws, event.data)
    end

    ws.on :close do |event|
      WS.on_close(ws)
    end

    # Return async Rack response
    ws.rack_response

  else
    # Normal HTTP request
    [200, {'Content-Type' => 'text/plain'}, ['Hello']]
  end
end

Faye::WebSocket.load_adapter('thin')
EM.next_tick do
  Thread.new do
    while true
      WS.inc_tick
      WS.send_clients_response(nil)
      sleep(0.001 * Settings.tick_size)
    end
  end


  EM.run {
    thin = Rack::Handler.get('thin')

    thin.run(App, :Port => 9292) do |server|
    end
  }
end
