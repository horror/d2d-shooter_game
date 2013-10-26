RESPAWN = "$"
VOID = "."
WALL = "#"
MOVE = "move"
DEFAULT_ACCELERATION = 0.1
EPSILON = 0.0000001
ACCURACY = 6

class Client
  def initialize(players, items, maps)
    @player = {vx: 0.0, vy: 0.0, x: 0.0, y: 0.0, hp: 100}
    @changed = false
    @initialized = false
    @teleported = false
    @players = players
    @maps = maps
    @items = items
  end

  def changed?
    @changed
  end

  def no_changes
    @changed = false
  end

  def game
    (@game_id ? @game_id : 0).to_s
  end

  def sid
    @sid
  end

  def on_message(ws, players, tick)
    return if !@initialized
    deceleration if not changed?
    no_changes
    ws.send(ActiveSupport::JSON.encode({tick: tick, players: players.values})) if players
  end

  def process(data, tick)
    params = data['params']
    return if !(user = User.find_by_sid(params["sid"])) || !(player = Player.find_by_user_id(user.id)) || (@initialized && tick > params['tick'])
    @changed = true
    @sid ||= params["sid"]

    if !@game_id #определяем игру для клиента, если еще небыла определена
      @game_id = player.game_id
      @players[game] ||= Hash.new
      @players[game][@sid] = to_player
    end

    init_position_new_player(player) if !@initialized

    send(data["action"], params)
  end

  def init_position_new_player(player)
    init_map_for_curr_game(player) if !@maps[game]
    @bottom_bound = @maps[game].size.to_f
    @right_bound = @maps[game][0].length.to_f

    init_items_for_curr_game if !@items[game]

    resp = define_respawn
    set_position(resp[:x] + 0.5, resp[:y] + 0.5)
    @initialized = true
  end

  def define_respawn
    @items[game]["respawns"][rand(@items[game]["respawns"].size - 1)]
  end

  def init_map_for_curr_game(player)
    @maps[game] = ActiveSupport::JSON.decode(player.game.map.map)
  end

  def init_items_for_curr_game
    @items[game] = Hash.new
    @items[game]["respawns"] = Array.new
    @items[game]["teleports"] = Hash.new
    for i in 0..@bottom_bound - 1
      for j in 0..@right_bound - 1
        @items[game]["respawns"] << {x: j, y: i} if @maps[game][i][j] == RESPAWN
        if ("0".."9").include?(@maps[game][i][j])
          @items[game]["teleports"][@maps[game][i][j].to_s] ||= Array.new
          @items[game]["teleports"][@maps[game][i][j].to_s] << {x: j, y: i}
        end
      end
    end
  end

  def set_position(x, y)
    @player[:x] = x.round(ACCURACY)
    @player[:y] = y.round(ACCURACY)
  end

  def move_position
    symbol = @maps[game][y = (@player[:y] + @player[:vy]).floor][x = (@player[:x] + @player[:vx]).floor]
    @teleported = false if symbol == VOID or symbol == RESPAWN
    make_tp(x, y) if ("0".."9").include?(symbol) && !@teleported
    stop_movement if symbol == WALL

    @player[:x] += @player[:vx]
    @player[:y] += @player[:vy]
    set_position([[0.0, @player[:x]].max, @right_bound].min, [[0.0, @player[:y]].max, @bottom_bound].min)
  end

  def make_tp(x, y)
    tps = @items[game]["teleports"][@maps[game][y][x]]
    tp = (tps[0][:x] == x and tps[0][:y] == y ? tps[1] : tps[0])
    set_position(tp[:x].to_f + 0.5, tp[:y].to_f + 0.5)
    @teleported = true
  end

  def normalize(dx, dy)
    return 0, 0 if (norm = Math.sqrt(dx.to_f**2 + dy.to_f**2)) == 0.0
    dx /= norm
    dy /= norm
    return dx, dy
  end

  def change_velocity(dx, dy)
    dx, dy = normalize(dx, dy)
    @player[:vx] = (@player[:vx] + dx * DEFAULT_ACCELERATION).round(ACCURACY)
    @player[:vy] = (@player[:vy] + dy * DEFAULT_ACCELERATION).round(ACCURACY)
  end

  def stop_movement
    @player[:vx] = 0.0
    @player[:vy] = 0.0
  end

  def deceleration
    change_velocity(-@player[:vx], -@player[:vy])
    move_position
  end

  def to_player
    @player
  end

  ###ACTIONS###
  def move(data)
    change_velocity(data["dx"], data["dy"])
    move_position
  end
end