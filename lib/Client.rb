RESPAWN = "$"
VOID = "."
WALL = "#"
MOVE = "move"

def v_sign(num)
  return num.to_f.abs < Settings.eps ? 0.0 : num.to_f > 0.0 ? 1 : -1
end

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

  def symbol(x, y)
    return map[y + 1][x + 1]
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
    @map = ["#" * (@map[0].size + 2)] + @map.map{|i| i = "#" + i + "#"} + ["#" * (@map[0].size + 2)]
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
    @consts = {}
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
    @consts = {accel: player_model.game.accel, max_velocity: player_model.game.max_velocity,
               friction: player_model.game.friction, gravity: player_model.game.gravity}
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
    return if try_tp || try_bump

    set_position(player[:x] + player[:vx], player[:y] + player[:vy])
  end

  end

  def try_bump
    x = (player[:x] + player[:vx] + v_sign(player[:vx]) * 0.5 - Settings.eps*v_sign(player[:vx])).floor
    y = (player[:y] + player[:vy] + v_sign(player[:vy]) * 0.5 - Settings.eps*v_sign(player[:vy])).floor
    return false if game.symbol(x, y) != WALL

    x = player[:vx].abs < Settings.eps ? player[:x] : v_sign(player[:vx]) > 0 ? x - 0.5 : x + 1.5
    y = player[:vy].abs < Settings.eps ? player[:y] : v_sign(player[:vy]) > 0 ? y - 0.5 : y + 1.5
    stop_movement(x, y)
    return true
  end

  def try_tp
    x = (player[:x] + player[:vx] - Settings.eps*v_sign(player[:vx])).floor
    y = (player[:y] + player[:vy] - Settings.eps*v_sign(player[:vy])).floor

    @last_tp = {x: -1, y: -1} if game.symbol(x, y) == VOID or game.symbol(x, y) == RESPAWN
    if ("0".."9").include?(game.symbol(x, y)) && @last_tp != {x: x, y: y}
      make_tp(x, y)
      return true
    end

    return false
  end

  def make_tp(x, y)
    tps = game.items["teleports"][game.symbol(x,y)]
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
    player[:x] = x.round(Settings.accuracy)
    player[:y] = y.round(Settings.accuracy)
  end

  def deceleration
    player[:vx], player[:vy] = Client::new_velocity(-player[:vx], -player[:vy], player[:vx], player[:vy], @consts)
    move_position
  end

  def self.normalize(dx, dy)
    return 0, 0 if (norm = Math.sqrt(dx.to_f**2 + dy.to_f**2)) == 0.0
    dx /= norm
    dy /= norm
    return dx, dy
  end

  def self.new_velocity(dx, dy, vx, vy, consts)
    dx, dy = Client::normalize(dx, dy)
    vx = (vx + dx * consts[:accel]).round(Settings.accuracy)
    vy = (vy + dy * consts[:accel]).round(Settings.accuracy)
    return [vx.abs, consts[:max_velocity]].min * v_sign(vx), [vy.abs, consts[:max_velocity]].min * v_sign(vy)
  end

  ###ACTIONS###
  def move(data)
    player[:vx], player[:vy] = Client::new_velocity(data[:dx], data[:dy], player[:vx], player[:vy], @consts)
    move_position
  end
end
