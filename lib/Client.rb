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
  attr_accessor :players, :projectiles, :answered_players, :items, :map, :id, :map_bottom_bound, :map_right_bound

  def initialize(id, json_map)
    @players = Hash.new
    @projectiles = Hash.new
    @answered_players = Hash.new
    @map = Array.new
    @items = Hash.new

    items["respawns"] = Array.new
    items["teleports"] = Hash.new
    @id = id
    @map = ActiveSupport::JSON.decode(json_map)
    init_items
  end

  def get_players
    players.map do |sid, player|
      {x: (player[:coord].x - 1).round(Settings.accuracy), y: (player[:coord].y - 1).round(Settings.accuracy),
       vx: player[:velocity].x, vy: player[:velocity].y,
       hp: player[:hp],
       login: player[:login]}
    end
  end

  def get_projectiles
    result = Array.new
    projectiles.each do |owner, proj|
      result += proj.map do |projectile|
        {x: projectile[:coord].x - 1, y: projectile[:coord].y - 1,
         vx: Settings.def_game_consts[:gunVelocity], vy: Settings.def_game_consts[:gunVelocity],
         owner: owner}
      end
    end

    result
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

  attr_accessor :ws, :sid, :login, :game_id, :games, :player, :projectiles, :summed_move_params, :position_changed

  def initialize(ws, games)
    @player = {velocity: Point.new(0.0, 0.0), coord: Point.new(0.0, 0.0), hp: 100}
    @projectiles = Array.new
    @summed_move_params = Point.new(0.0, 0.0)
    @position_changed = false
    @initialized = false
    @last_tp = Point.new(-1, -1)
    @ws = ws
    @games = games
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

  def apply_changes
    return if !@initialized

    position_changed ? move(summed_move_params) : deceleration
    @summed_move_params = Point.new(0.0, 0.0)
    @position_changed = false
    move_projectiles

    game.players[sid] = player
    game.projectiles[login] = projectiles
  end

  def on_message(tick)
    return if !@initialized

    ws.send(ActiveSupport::JSON.encode({tick: tick, players: game.get_players, projectiles: game.get_projectiles})) if game
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
    player[:login] = login
    @initialized = true
  end

  def next_respawn
    items = game.items
    result = items["respawns"][items["last_respawn"]]
    items["last_respawn"] = items["last_respawn"] + 1 == items["respawns"].size ? 0 : items["last_respawn"] + 1
    return result
  end

  def move_position
    check_collisions
    return if try_tp

    set_position(player[:coord] + player[:velocity])
  end

  def calc_wall_offset(wall_cell, player_new_floor_cell, player_cell, der_vectors, der, wall_offset)
    return if !check_intersect(wall_cell, der_vectors)

    cell_pos = wall_cell - player_new_floor_cell
    offset = Settings.player_halfrect

    player_h_edge = Line.new(Point.new(player_cell.x, player_cell.y), Point.new(player_cell.x + offset * 2, player_cell.y))
    player_v_edge = Line.new(Point.new(player_cell.x, player_cell.y), Point.new(player_cell.x, player_cell.y + offset * 2))

    cell_h_edge = Line.new(wall_cell, Point.new(wall_cell.x + 1, wall_cell.y))
    cell_v_edge = Line.new(wall_cell, Point.new(wall_cell.x, wall_cell.y + 1))

    #сохранить смещение по Х до стенки, если она не находится над или под ячекой игрока, и если слева/справа от текущей стенки нету другой стенки,
    #и если нету пересечения проекций текущей стенки и ячейки игрока на ось Y
    if cell_pos.x != 0 && symbol(wall_cell.x - cell_pos.x, wall_cell.y) != WALL && !player_h_edge.prj_intersect(cell_h_edge, :x)
      wall_offset.x = (cell_pos.x == 1 ? wall_cell.x : wall_cell.x + 1) - (player[:coord].x + offset * cell_pos.x)
    end
    if cell_pos.y != 0 && symbol(wall_cell.x, wall_cell.y - cell_pos.y) != WALL && !player_v_edge.prj_intersect(cell_v_edge, :y)
      wall_offset.y = (cell_pos.y == 1 ? wall_cell.y : wall_cell.y + 1) - (player[:coord].y + offset * cell_pos.y)
    end

    bottom_left_cell = symbol(player_new_floor_cell.x - 1, player_new_floor_cell.y)
    bottom_right_cell = symbol(player_new_floor_cell.x + 1, player_new_floor_cell.y)
    #не обнулять компаненту X, если произашло столкновение с нижней левой/правой стенкой ровно в угол и нету стенок слева/стправа
    wall_offset.x = 1 if wall_offset.eq?(0, 0) && (der.x < 0 && bottom_left_cell != WALL || der.x > 0 && bottom_right_cell != WALL)
  end

  def check_intersect(wall_cell, der_vectors)
    #внутренние горизантальная и вертикальная грани текущей стенки
    cell_h_edge = Line.new(wall_cell, Point.new(wall_cell.x + 1, wall_cell.y))
    cell_v_edge = Line.new(wall_cell, Point.new(wall_cell.x, wall_cell.y + 1))

    #проверка пересечений проекций граней стенок со всеми векторами движения
    has_intersect = false
    der_vectors.each{|i|
      has_intersect ||= i.prj_intersect(cell_h_edge, :x) && i.prj_intersect(cell_v_edge, :y)
    }
    has_intersect
  end


  def check_collisions
    v_der = player[:velocity].map{|i| v_sign(i)}
    return if v_der.x == 0 && v_der.y == 0
    offset = Settings.player_halfrect
    #координаты(левая верхная точка) квадрата игрока до движения
    player_cell  = player[:coord] - offset
    #координаты ячейки в которой находится начало вектора движения игрока
    player_new_floor_cell = (player[:coord] + v_der * offset - v_der * Settings.eps).map{|i| i.floor}
    #смещение до стенок по x,y
    wall_offset = Point.new(1, 1)
    #массив векторов движения игрока
    der_vectors = Array.new()
    #движение вправо/влево или вверх/вниз
    der_vectors.push Line.new(player[:coord] + v_der * offset,
                              player[:coord] + v_der * offset + player[:velocity])                    if v_der.y == 0 || v_der.x == 0
    #движение влево-вверх
    der_vectors.push Line.new(player_cell, player_cell + player[:velocity])                             if v_der.y < 0 || v_der.x < 0
    #движение вправо-вверх
    der_vectors.push Line.new(Point.new(player_cell.x + offset * 2, player_cell.y),
                              Point.new(player_cell.x + offset * 2, player_cell.y) + player[:velocity]) if v_der.y < 0 || v_der.x > 0
    #движение влево-вниз
    der_vectors.push Line.new(Point.new(player_cell.x, player_cell.y + offset * 2),
                              Point.new(player_cell.x, player_cell.y + offset * 2) + player[:velocity]) if v_der.y > 0 || v_der.x < 0
    #движение вправо-вниз
    der_vectors.push Line.new(player_cell + offset * 2, player_cell + offset * 2 + player[:velocity])   if v_der.y > 0 || v_der.x > 0

    #перебор по всем стенкам вокруг player_cell
    (-1..1).each{ |i|
      (-1..1).each{ |j|
        maybe_wall_cell = player_new_floor_cell + Point.new(j, i)
        calc_wall_offset(maybe_wall_cell, player_new_floor_cell, player_cell, der_vectors, v_der, wall_offset) if symbol(maybe_wall_cell) == WALL
      }
    }
    #смещение = 1,1 => столкновения не было
    return false if wall_offset.eq?(1, 1)
    player[:velocity].set(wall_offset.x != 1 ? 0 : player[:velocity].x, wall_offset.y != 1 ? 0 : player[:velocity].y)
    player[:coord] = player[:coord] + Point.new(wall_offset.x == 1 ? 0 : wall_offset.x, wall_offset.y == 1 ? 0 : wall_offset.y)
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

  def move_projectiles
    projectiles.delete_if do |projectile|
      intersected = false
      old_coord = projectile[:coord]
      projectile[:coord] += projectile[:der] * Settings.def_game_consts[:gunVelocity]
      der = Line.new(old_coord, projectile[:coord])
      v_der = projectile[:der].map{|i| v_sign(i)}
      coord_floor_cell = (old_coord - v_der * Settings.eps).map{|i| i.floor}
      (-1..1).each{ |i|
        (-1..1).each{ |j|
          maybe_wall_cell = coord_floor_cell + Point.new(j, i)
          if symbol(maybe_wall_cell) == WALL && check_intersect(maybe_wall_cell, [der])
            intersected = true
          end
        }
      }
      intersected
    end
  end

  ###ACTIONS###
  def move(data)
    player[:velocity] = Client::new_velocity(data, player[:velocity], has_floor, @consts)
    move_position
  end

  def fire(data)
    projectiles << {coord: player[:coord], der: Client::normalize(Point.new(data["dx"], data["dy"])), type: "gun"}
  end
end
