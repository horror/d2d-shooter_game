RESPAWN = "$"
VOID = "."
WALL = "#"
MOVE = "move"

def f_eq(a, b)
  (a - b).abs < Settings.eps
end

def v_sign(num)
  return f_eq(num.to_f, 0) ? 0.0 : num.to_f > 0.0 ? 1 : -1
end

class Point
  attr_accessor :x, :y

  def initialize(x, y)
    set(x, y)
  end

  def set(x, y)
    @x = x
    @y = y
  end

  def +(arg)
    return Point.new(x + arg.x, y + arg.y) if arg.kind_of?(Point)
    return Point.new(x + arg, y + arg) if arg.kind_of?(Numeric)
  end

  def -(arg)
    return Point.new(x - arg.x, y - arg.y) if arg.kind_of?(Point)
    return Point.new(x - arg, y - arg) if arg.kind_of?(Numeric)
  end

  def *(arg)
    return Point.new(x * arg.x, y * arg.y) if arg.kind_of?(Point)
    return Point.new(x * arg, y * arg) if arg.kind_of?(Numeric)
  end

  def neg
    return Point.new(-x, -y)
  end

  def ==(point)
    f_eq(x, point.x) && f_eq(y, point.y)
  end

  def eq?(x, y)
    f_eq(@x, x) && f_eq(@y, y)
  end

  def map(&proc)
    new_x = proc.call(@x)
    new_y = proc.call(@y)
    return Point.new(new_x, new_y)
  end
end

class Line
  attr_accessor :p1, :p2

  def initialize(p1, p2)
    @p1 = p1
    @p2 = p2
  end

  def prj_intersect(line, v_der)
    return intersect_by_coords(p1.send(v_der), p2.send(v_der), line.p1.send(v_der), line.p2.send(v_der))
  end

  private

  def intersect_by_coords(a_1, a_2, b_1, b_2)
    a_1, a_2 = [a_1, a_2].min, [a_1, a_2].max
    b_1, b_2 = [b_1, b_2].min, [b_1, b_2].max
    return !f_eq(a_2, b_1) && !f_eq(a_1, b_2) && a_2 > b_1 && b_2 > a_1
  end
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

  def init_items
    @map_bottom_bound = map.size.to_i
    @map_right_bound = map[0].length.to_i
    @map = ["#" * (@map[0].size + 2)] + @map.map{|i| i = "#" + i + "#"} + ["#" * (@map[0].size + 2)]
    for i in 0..map.size.to_i - 1
      for j in 0..map[0].length.to_i - 1
        items["respawns"] << Point.new(j, i) if map[i][j] == RESPAWN
        if ("0".."9").include?(map[i][j])
          items["teleports"][map[i][j].to_s] ||= Array.new
          items["teleports"][map[i][j].to_s] << Point.new(j, i)
        end
      end
    end
    items['last_respawn'] = 0
  end
end

class Client

  attr_accessor :ws, :sid, :game_id, :games, :player, :summed_move_params

  def initialize(ws, games)
    @player = {velocity: Point.new(0.0, 0.0), coord: Point.new(0.0, 0.0), hp: 100}
    @summed_move_params = Point.new(0.0, 0.0)
    @position_changed = false
    @initialized = false
    @last_tp = Point.new(-1, -1)
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

  def symbol(arg_1, arg_2 = nil)
    return arg_2 ? game.map[arg_2][arg_1] : game.map[arg_1.y][arg_1.x]
  end

  def on_message(tick)
    return if !@initialized

    position_changed? ? move(summed_move_params) : deceleration
    result = {x: (player[:coord].x - 1).round(Settings.accuracy), y: (player[:coord].y - 1).round(Settings.accuracy),
              vx: player[:velocity].x, vy: player[:velocity].y,
              hp: player[:hp]}
    game.players[sid] = result
    @summed_move_params = Point.new(0.0, 0.0)
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
      summed_move_params.x += params["dx"].to_f
      summed_move_params.y += params["dy"].to_f
      @position_changed = true
    else
      send(data["action"], params)
    end
  end

  def init_player
    resp = next_respawn
    set_position(resp + 0.5)

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
    coord = (player[:coord] + player[:velocity] - player[:velocity].map{|i| Settings.eps * v_sign(i)}).map{|i| i.floor}
    @last_tp.set(-1, -1) if symbol(coord) == VOID or symbol(coord) == RESPAWN
    if ("0".."9").include?(symbol(coord)) && !(@last_tp == coord)
      make_tp(coord)
      return true
    end

    return false
  end

  def make_tp(coord)
    tps = game.items["teleports"][symbol(coord)]
    tp = tps[0] == coord ? tps[1] : tps[0]
    set_position(tp + 0.5)
    @last_tp.set(tp.x, tp.y)
  end

  def set_position(new_pos)
    player[:coord] = new_pos.map{|i| i.round(Settings.accuracy)}
  end

  def deceleration
    player[:velocity].y += @consts[:gravity] if !has_floor
    player[:velocity].x = player[:velocity].x.abs <= @consts[:friction] ? 0 :
                          player[:velocity].x - v_sign(player[:velocity].x) * @consts[:friction]
    player[:velocity] = player[:velocity].map{|i| [i.abs, @consts[:max_velocity]].min.round(Settings.accuracy) * v_sign(i)}
    move_position
  end

  def self.normalize(der)
    return Point.new(0, 0) if (norm = Math.sqrt(der.x.to_f**2 + der.y.to_f**2)) == 0.0
    return der.map{|i| i /= norm}
  end

  def has_floor
    y = (player[:coord].y + Settings.player_halfrect).floor
    x1 = (player[:coord].x - Settings.player_halfrect + Settings.eps).floor
    x2 = (player[:coord].x + Settings.player_halfrect - Settings.eps).floor
    return symbol(x1, y) == WALL || symbol(x2, y) == WALL
  end

  def self.new_velocity(der, velocity, has_floor, consts)
    der = Client::normalize(der)
    velocity.y += consts[:gravity] if !has_floor
    velocity.y = -consts[:max_velocity] if has_floor && der.y < 0
    velocity.set((velocity.x + der.x * consts[:accel]).round(Settings.accuracy), velocity.y.round(Settings.accuracy))
    return velocity.map{|i| [i.abs, consts[:max_velocity]].min * v_sign(i)}
  end

  ###ACTIONS###
  def move(data)
    player[:velocity] = Client::new_velocity(data, player[:velocity], has_floor, @consts)
    move_position
  end
end
