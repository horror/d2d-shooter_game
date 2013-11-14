RESPAWN = "$"
VOID = "."
WALL = "#"
MOVE = "move"
DEFAULT_ACCELERATION = 0.02
EPSILON = 1e-7
ACCURACY = 6
MAX_VELOCITY = 0.2

class ActiveGame
  attr_accessor :players, :answered_players, :items, :map, :id, :map_bottom_bound, :map_right_bound

  def initialize(id, json_map)
    @players = Hash.new
    @answered_players = Hash.new
    @map = Array.new
    @items = Hash.new


    items["respawns"] = Array.new
    items["teleports"] = Hash.new
    @id = id
    @map = ActiveSupport::JSON.decode(json_map)
    init_items
  end

  def init_items
    @map_bottom_bound = map.size.to_i
    @map_right_bound = map[0].length.to_i

    for i in 0..map_bottom_bound - 1
      for j in 0..map_right_bound - 1
        items["respawns"] << {x: j, y: i} if map[i][j] == RESPAWN
        if ("0".."9").include?(map[i][j])
          items["teleports"][map[i][j].to_s] ||= Array.new
          items["teleports"][map[i][j].to_s] << {x: j, y: i}
        end
      end
    end
    items['last_respawn'] = 0
  end
end

class Client

  attr_accessor :ws, :sid, :game_id, :games, :player, :summed_move_params

  def initialize(ws, games)
    @player = {vx: 0.0, vy: 0.0, x: 0.0, y: 0.0, hp: 100}
    @summed_move_params = {dx: 0.0, dy: 0.0}
    @position_changed = false
    @initialized = false
    @last_tp = {x: -1, y: -1}
    @ws = ws
    @games = games
    @login = ""
  end

  def position_changed?
    @position_changed
  end

  def game
    game_id ? games[game_id] : nil
  end

  def on_message(tick)
    return if !@initialized

    if position_changed?
      move(summed_move_params)
      game.players[sid] = player
    else
      deceleration
    end

    @summed_move_params = {dx: 0.0, dy: 0.0}
    @position_changed = false
    ws.send(ActiveSupport::JSON.encode({tick: tick, players: game.players.values})) if game
  end

  def process(data, tick)
    params = data['params']

    return if !(user = User.find_by_sid(params["sid"])) || !(player_model = Player.find_by_user_id(user.id)) || (@initialized && tick > params['tick'])

    @login ||= user.login
    @game_id ||= player_model.game_id
    @sid ||= params["sid"]
    games[game_id] = ActiveGame.new(game_id, player_model.game.map.map) if !@games.include?(game_id)

    init_player if !@initialized

    if data["action"] == MOVE
      summed_move_params[:dx] += params["dx"].to_f
      summed_move_params[:dy] += params["dy"].to_f
      @position_changed = true
    else
      send(data["action"], params)
    end
  end

  def init_player
    resp = next_respawn
    set_position(resp[:x] + 0.5, resp[:y] + 0.5)

    @initialized = true
  end

  def next_respawn
    items = game.items
    result = items["respawns"][items["last_respawn"]]
    items["last_respawn"] = items["last_respawn"] + 1 == items["respawns"].size ? 0 : items["last_respawn"] + 1
    return result
  end

  def move_position
    return if try_tp
    return if try_bump

    set_position(player[:x] + player[:vx], player[:y] + player[:vy])

    out_of_bounds_correction
  end

  def out_of_bounds_correction
    if (player[:x] < 0.5 || player[:x] > game.map_right_bound.to_f - 0.5 ||
       player[:y] < 0.5 || player[:y] > game.map_bottom_bound.to_f - 0.5
    )
      stop_movement([[0.5, player[:x]].max, game.map_right_bound.to_f - 0.5].min,
                    [[0.5, player[:y]].max, game.map_bottom_bound.to_f - 0.5].min)
    end
  end

  def try_bump
    x = (player[:x] + player[:vx] + v_sign(player[:vx]) * 0.5 - EPSILON*v_sign(player[:vx])).floor
    y = (player[:y] + player[:vy] + v_sign(player[:vy]) * 0.5 - EPSILON*v_sign(player[:vy])).floor
    symbol = x < 0.0 || y < 0.0 ? "" : game.map[y][x]
    x = player[:vx].abs < EPSILON ? player[:x] : v_sign(player[:vx]) > 0 ? x - 0.5 : x + 1.5
    y = player[:vy].abs < EPSILON ? player[:y] : v_sign(player[:vy]) > 0 ? y + 1.5 : y - 0.5
    if symbol == WALL
      stop_movement(x, y)
      return true
    end
    return false
  end

  def try_tp
    x = (player[:x] + player[:vx] - EPSILON*v_sign(player[:vx])).floor
    y = (player[:y] + player[:vy] - EPSILON*v_sign(player[:vy])).floor

    symbol = x < 0.0 || y < 0.0 ? "" : game.map[y][x]
    @last_tp = {x: -1, y: -1} if symbol == VOID or symbol == RESPAWN

    if ("0".."9").include?(symbol) && @last_tp != {x: x, y: y}
      make_tp(x, y)
      return true
    end

    return false
  end

  def make_tp(x, y)
    tps = game.items["teleports"][game.map[y][x]]
    tp = tps[0][:x] == x && tps[0][:y] == y ? tps[1] : tps[0]
    set_position(tp[:x].to_f + 0.5, tp[:y].to_f + 0.5)
    @last_tp = tp
  end

  def stop_movement(x, y)
    player[:vx] = 0.0
    player[:vy] = 0.0
    set_position(x, y)
  end

  def set_position(x, y)
    player[:x] = x.round(ACCURACY)
    player[:y] = y.round(ACCURACY)
  end

  def deceleration
    player[:vx], player[:vy] = new_velocity(-player[:vx], -player[:vy], player[:vx], player[:vy])
    move_position
  end

  def v_sign(num)
    return num.to_f.abs < EPSILON ? 0.0 : num.to_f > 0.0 ? 1 : -1
  end

  def normalize(dx, dy)
    return 0, 0 if (norm = Math.sqrt(dx.to_f**2 + dy.to_f**2)) == 0.0
    dx /= norm
    dy /= norm
    return dx, dy
  end

  def new_velocity(dx, dy, vx, vy)
    dx, dy = normalize(dx, dy)
    vx = (vx + dx * DEFAULT_ACCELERATION).round(ACCURACY)
    vy = (vy + dy * DEFAULT_ACCELERATION).round(ACCURACY)
    return [vx.abs, MAX_VELOCITY].min * v_sign(vx), [vy.abs, MAX_VELOCITY].min * v_sign(vy)
  end

  ###ACTIONS###
  def move(data)
    player[:vx], player[:vy] = new_velocity(data[:dx], data[:dy], player[:vx], player[:vy])
    move_position
  end
end
