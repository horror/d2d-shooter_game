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
    puts "klients"
    puts clients.size
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

  def self.run_periodic_timer
    @start = @next = Time.now.to_f
    @interval = Settings.tick_size / 1000.0
    @i = 0
    @old_i = 0
    Thread.new do
      while(true) do
        WS.inc_tick
        WS.send_clients_response(nil)
        sleep(@interval)
        @i += 1
        if (Time.now.to_f >= @next)
          #puts "now tiks"
          @next = Time.now.to_f + 1.0
          #puts @i - @old_i
          @old_i = @i
        end
      end
    end
  end

  def self.start
    WS.run_periodic_timer

    Thread.new do
      @server = Rubame::Server.new("0.0.0.0", 8001)
      @interval = Settings.tick_size / 1000.0
      while true
        @server.run do |client|
          client.onopen do
            WS.on_open(client)
            puts "Server reports:  client open"
          end
          client.onmessage do |msg|
            WS.on_message(client, msg)
            puts "Server reports:  message received: #{msg}"
          end
          client.onclose do
            WS.on_close(client)
            puts "Server reports:  client closed"
          end
        end
        sleep(@interval)
      end
    end
  end

end


WS.start
