RESPAWN = "$"
VOID = "."
WALL = "#"
MOVE = "move"
DEFAULT_ACCELERATION = 0.1
EPSILON = 1e-7
ACCURACY = 6
MAX_VELOCITY = 1

def v_sign(num)
  return num.to_f == 0.0 ? 0.0 : num.to_f > 0.0 ? 1 : -1
end

def normalize(dx, dy)
  return 0, 0 if (norm = Math.sqrt(dx.to_f**2 + dy.to_f**2)) == 0.0
  dx /= norm
  dy /= norm
  return dx, dy
end

def new_velocity(dx, dy, vx, vy)
  dx, dy = normalize(dx, dy)
  #puts "login = #{@login}, vx = #{vx}, DX = #{dx * DEFAULT_ACCELERATION}, vx + DX = #{[(vx + dx * DEFAULT_ACCELERATION).round(ACCURACY), MAX_VELOCITY].min}"
  vx, vy = (vx + dx * DEFAULT_ACCELERATION).round(ACCURACY), (vy + dy * DEFAULT_ACCELERATION).round(ACCURACY)
  return [vx.abs, MAX_VELOCITY].min * v_sign(vx), [vy.abs, MAX_VELOCITY].min * v_sign(vy)
end

class Client

  def initialize(players, items, maps)
    @player = {vx: 0.0, vy: 0.0, x: 0.0, y: 0.0, hp: 100}
    @changed = false
    @initialized = false
    @last_tp = {x: -1, y: -1}
    @players = players
    @maps = maps
    @items = items

    @login = ""
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
    @login = user.login
    @changed = true
    @sid ||= params["sid"]

    if !@game_id #определяем игру для клиента, если еще небыла определена
      @game_id = player.game_id
      @players[game] ||= Hash.new
    end

    init_position_new_player(player) if !@initialized

    send(data["action"], params)
    @players[game][@sid] = to_player
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
    x, y = (@player[:x] + @player[:vx]).floor, (@player[:y] + @player[:vy]).floor
    symbol = x < 0.0 || y < 0.0 ? "" : @maps[game][y][x]
    @last_tp = {x: -1, y: -1} if symbol == VOID or symbol == RESPAWN
    #puts "symbol = " + symbol, "istp = " + @teleported.to_s, "x ,y = " + x.to_s + ", " + y.to_s
    if ("0".."9").include?(symbol) && @last_tp != {x: x, y: y}
      make_tp(x, y)
      return
    end

    x = (@player[:x] + @player[:vx] + v_sign(@player[:vx]) * 0.5 + EPSILON*v_sign(@player[:vx])).floor
    y = (@player[:y] + @player[:vy] + v_sign(@player[:vy]) * 0.5 + EPSILON*v_sign(@player[:vx])).floor
    symbol = x < 0.0 || y < 0.0 ? "" : @maps[game][y][x]
    x = v_sign(@player[:vx]) == 0 ? @player[:x] : v_sign(@player[:vx]) > 0 ? x - 0.5 : x + 1.5
    y = v_sign(@player[:vy]) == 0 ? @player[:y] : v_sign(@player[:vy]) > 0 ? y + 1.5 : y - 0.5
    if symbol == WALL
      stop_movement(x, y)
      return
    end

    set_position(@player[:x] + @player[:vx], @player[:y] + @player[:vy])

    if @player[:x] < 0.5 || @player[:x] > @right_bound - 0.5 || @player[:y] < 0.5 || @player[:y] > @bottom_bound - 0.5
      stop_movement([[0.5, @player[:x]].max, @right_bound - 0.5].min, [[0.5, @player[:y]].max, @bottom_bound - 0.5].min)
    end
  end

  def make_tp(x, y)
    tps = @items[game]["teleports"][@maps[game][y][x]]
    tp = tps[0][:x] == x && tps[0][:y] == y ? tps[1] : tps[0]
    set_position(tp[:x].to_f + 0.5, tp[:y].to_f + 0.5)
    @last_tp = tp
  end

  def stop_movement(x, y)
    @player[:vx] = 0.0
    @player[:vy] = 0.0
    set_position(x, y)
  end

  def deceleration
    @player[:vx], @player[:vy] = new_velocity(-@player[:vx], -@player[:vy], @player[:vx], @player[:vy])
    move_position
  end

  def to_player
    @player
  end

  ###ACTIONS###
  def move(data)
    @player[:vx], @player[:vy] = new_velocity(data["dx"], data["dy"], @player[:vx], @player[:vy])
    move_position
  end
end
