RESPAWN = "$"
VOID = "."
WALL = "#"
HEAL = "h"
GUN = "P"
MACHINE_GUN = "M"
ROCKET_LAUNCHER = "R"
RAIL_GUN = "A"
KNIFE = "K"
MOVE = "move"
ALIVE = "alive"
DEAD = "dead"

def f_eq(a, b)
  (a - b).abs < Settings.eps
end

def v_sign(num)
  return f_eq(num.to_f, 0) ? 0.0 : num.to_f > 0.0 ? 1 : -1
end

class Geometry

  def self.check_intersect(wall_cell, der_vectors)
    #внутренние горизантальная и вертикальная грани текущей стенки
    cell_h_edge = Line(wall_cell, Point(wall_cell.x + 1, wall_cell.y))
    cell_v_edge = Line(wall_cell, Point(wall_cell.x, wall_cell.y + 1))

    #проверка пересечений проекций граней стенок со всеми векторами движения
    has_intersect = false
    der_vectors.each {|i|
      has_intersect ||= i.prj_intersect(cell_h_edge, :x) && i.prj_intersect(cell_v_edge, :y)
    }
    has_intersect
  end

  def self.walk_cells_around_coord(coord, velocity, is_rect, &block)
    v_der = velocity.map{|i| v_sign(i)}
    offset = is_rect ? Settings.player_halfrect : 0
    a_cell = (coord + v_der * offset - v_der * Settings.eps).map{|i| i.floor}

    (-1..1).each{ |i|
      (-1..1).each{ |j|
        block.call(a_cell + Point(j, i))
      }
    }
  end

  def self.scalar_prod(p1, p2)
    p1.x * p2.x + p1.y * p2.y
  end

  def self.polygon_include_point?(start_rect_point, end_rect_point, point)
    p1, p2 = start_rect_point, end_rect_point
    return false if p1 == p2
    offset = Settings.player_halfrect - Settings.eps
    der = (p2 - p1).map{|i| f_eq(i.to_f, 0) || i.to_f > 0.0 ? 1 : -1} * offset
    poly = [Point(p1.x - der.x, p1.y + der.y), p1 - der, Point(p1.x + der.x, p1.y - der.y),
            Point(p2.x + der.x, p2.y - der.y), p2 + der, Point(p2.x - der.x, p2.y + der.y)]
    prj_x = [poly[0].x, poly[0].x]
    prj_y = [poly[0].y, poly[0].y]
    poly.each{ |i|
      prj_x = [[prj_x[0], i.x].min, [prj_x[1], i.x].max]
      prj_y = [[prj_y[0], i.y].min, [prj_y[1], i.y].max]
    }
    diag_prj_intersect = true
    if !f_eq(p1.x, p2.x) && !f_eq(p1.y, p2.y)
      #Нормаль к диагональной грани полигона
      normal = Line(Point(-poly[1].y, poly[1].x), Point(-poly[2].y, poly[2].x))
      normal_p = normal.p2 - normal.p1
      #Проекция полигона на нормаль
      prj_normal = [Geometry::scalar_prod(normal_p, poly[1]), Geometry::scalar_prod(normal_p, poly[1])]
      poly.each{ |i|
        prj_normal = [[prj_normal[0], Geometry::scalar_prod(normal_p, i)].min, [prj_normal[1], Geometry::scalar_prod(normal_p, i)].max]
      }
      #Проверка пересечения проекций точки и полигона на нормаль
      diag_prj_intersect = Geometry::scalar_prod(normal_p, point) > prj_normal[0] && Geometry::scalar_prod(normal_p, point) < prj_normal[1]
    end
    return diag_prj_intersect && point.x > prj_x[0] && point.x < prj_x[1] && point.y > prj_y[0] && point.y < prj_y[1]
  end

  def self.rect_include_point?(center, point)
    top_right = (center + Settings.player_halfrect).map{|i| i.round(Settings.accuracy)}
    bottom_left = (center - Settings.player_halfrect).map{|i| i.round(Settings.accuracy)}
    point.x > bottom_left.x && point.x < top_right.x && point.y > bottom_left.y && point.y < top_right.y
  end

  def self.line_len(p1, p2)
    Math::sqrt((p1.x - p2.x)**2 + (p1.y - p2.y)**2)
  end

  def self.dist(vector)
    Math.sqrt(vector.x.to_f**2 + vector.y.to_f**2)
  end

  def self.to_degrees(angle)
    angle * 180 / Math::PI
  end

  def self.compute_angle(v)
      (v.y < 0) ?
          Geometry::to_degrees(Math.acos(-v.x / Geometry::dist(v))) + 180 :
          Geometry::to_degrees(Math.acos(v.x / Geometry::dist(v)))
  end

  def self.normalize(der)
    return Point(0, 0) if (norm = Geometry::dist(der)) == 0.0
    return der.map{|i| i /= norm}
  end
end

class Point
  attr_accessor :x, :y

  def initialize(x, y)
    set(x, y)
  end

  def set(*args)
    return set(args[0].x, args[0].y) if args.size == 1
    @x = args[0]
    @y = args[1]
    self
  end

  def +(arg)
    return Point(x + arg.x, y + arg.y) if arg.kind_of?(Point)
    return Point(x + arg, y + arg) if arg.kind_of?(Numeric)
  end

  def -(arg)
    return Point(x - arg.x, y - arg.y) if arg.kind_of?(Point)
    return Point(x - arg, y - arg) if arg.kind_of?(Numeric)
  end

  def *(arg)
    return Point(x * arg.x, y * arg.y) if arg.kind_of?(Point)
    return Point(x * arg, y * arg) if arg.kind_of?(Numeric)
  end

  def /(arg)
    return Point(x / arg.x, y / arg.y) if arg.kind_of?(Point)
    return Point(x / arg, y / arg) if arg.kind_of?(Numeric)
  end

  def neg
    return Point(-x, -y)
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
    return Point(new_x, new_y)
  end

  def to_s
    x.to_s + " - " + y.to_s
  end
end

class Line
  attr_accessor :p1, :p2

  def initialize(p1, p2)
    @p1 = p1
    @p2 = p2
    self
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

def Point(x, y)
  Point.new(x, y)
end

def Line(p1, p2)
  Line.new(p1, p2)
end

class ActiveGame
  attr_accessor :clients, :items, :spawns, :last_spawn, :teleports, :projectiles, :map, :id, :item_pos_to_idx

  def initialize(id, json_map)
    @clients = Hash.new
    @map = Array.new
    @items = Array.new
    @spawns = Array.new
    @teleports = Hash.new
    @projectiles = Array.new
    @item_pos_to_idx = Hash.new

    @id = id
    @map = ActiveSupport::JSON.decode(json_map)
    init_items
  end

  def symbol(*args)
    return args.size == 2 ? map[args[1] + 1][args[0] + 1] : map[args[0].y + 1][args[0].x + 1]
  end

  def get_items
    items
  end

  def get_players
    clients.map do |sid, client|
      p = client.player
      [
        p[:coord].x.round(Settings.accuracy), p[:coord].y.round(Settings.accuracy),
        p[:velocity].x.round(Settings.accuracy), p[:velocity].y.round(Settings.accuracy),
        p[:weapon], p[:weapon_angle].to_i, p[:login], p[:hp], p[:respawn]
      ]
    end
  end

  def get_projectiles
    projectiles.map do |p|
      [
          p[:coord].x.round(Settings.accuracy), p[:coord].y.round(Settings.accuracy),
          p[:velocity].x.round(Settings.accuracy), p[:velocity].y.round(Settings.accuracy), p[:weapon], p[:ticks]
      ]
    end
  end

  def projectile_intersects?(projectile)
    intersected = false
    old_coord = projectile[:coord]
    v_der = projectile[:velocity]
    dm = Settings.def_game.weapons[projectile[:weapon]].damage
    r = Settings.def_game.weapons[projectile[:weapon]].radius
    new_coord = old_coord + v_der
    der = Line(old_coord, new_coord)

    Geometry::walk_cells_around_coord(old_coord, v_der, false) {|itr_cell|
      intersected = true if symbol(itr_cell) == WALL && Geometry::check_intersect(itr_cell, [der])
    }

    clients.each do |c_sid, client|
      c_player = client.player
      if client.login != projectile[:owner] && c_player[:status] == ALIVE && Geometry::check_intersect(c_player[:coord] - Point(0.5, 0.5), [der])
        client.get_damaged(dm)
        intersected = true
        break
      end
    end

    projectile[:coord] = new_coord
    damage_players_on_area(new_coord, r, dm) if projectile[:weapon] == ROCKET_LAUNCHER && intersected
    intersected
  end

  def damage_players_on_area(center, radius, damage)
    clients.each do |c_sid, client|
      c_player = client.player
      if c_player[:status] == ALIVE && Geometry::line_len(center, c_player[:coord]) <= radius
        client.get_damaged(damage)
        der = Geometry::normalize(c_player[:coord] - center)
        client.player[:velocity] = der * Settings.def_game.consts.maxVelocity
        client.move_position
      end
    end
  end


  def move_projectiles
    projectiles.delete_if do |projectile|
      need_delete = projectile[:velocity] == Point.new(0, 0) || projectile_intersects?(projectile)
      projectile[:ticks] += 1
      projectile[:velocity] = Point.new(0, 0) if [RAIL_GUN, KNIFE].include?(projectile[:weapon])
      if need_delete && projectile[:weapon] == ROCKET_LAUNCHER && projectile[:velocity] != Point.new(0, 0)
        projectile[:velocity] = Point.new(0, 0)
        need_delete = false
      end
      need_delete
    end
  end

  def apply_changes
    move_projectiles

    @items = items.map { |item| [item - 1, 0].max }
  end

  def init_items
    for i in 0..map.size.to_i - 1
      for j in 0..map[0].length.to_i - 1
        spawns << Point(j, i) if map[i][j] == RESPAWN
        if ("0".."9").include?(map[i][j])
          teleports[map[i][j].to_s] ||= Array.new
          teleports[map[i][j].to_s] << Point(j, i)
        end
        if map[i][j] =~ /[a-z]/i
          item_pos_to_idx[Point.new(j, i).to_s] = items.size
          items << 0
        end
      end
    end
    @map = ["#" * (@map[0].size + 2)] + @map.map{|i| i = "#" + i + "#"} + ["#" * (@map[0].size + 2)]
    @last_spawn = 0
  end
end

class Client

  attr_accessor :ws, :sid, :login, :game_id, :games, :player, :summed_move_params, :position_changed, :answered, :ticks_after_last_fire

  def initialize(ws, games)
    @player = {velocity: Point(0.0, 0.0), coord: Point(0.0, 0.0), hp: Settings.def_game.maxHP, status: ALIVE, respawn: 0, weapon: KNIFE}
    @summed_move_params = Point(0.0, 0.0)
    @position_changed = false
    @initialized = false
    @wall_offset = Point(-1, -1)
    @ticks_after_last_fire = 0
    @ws = ws
    @games = games
    @answered = true
    @consts = {}
  end

  def position_changed?
    @position_changed
  end

  def game
    game_id ? games[game_id] : nil
  end

  def apply_changes
    return if !@initialized
    move(summed_move_params)

    @summed_move_params = Point(0.0, 0.0)
    @position_changed = false
    @ticks_after_last_fire += 1
    if player[:status] == DEAD
      player[:respawn] -= 1
      if player[:respawn] == 0
        player[:status] = ALIVE
        init_player
      end
    end
  end

  def on_message(tick)
    return if !@initialized

    ws.send(ActiveSupport::JSON.encode({tick: tick, players: game.get_players, projectiles: game.get_projectiles, items: game.get_items})) if game
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

    if !@initialized
      init_player
      game.clients[sid] = self
    end

    return if player[:status] == DEAD
    return if f_eq(params["dx"], 0) && f_eq(params["dy"], 0)
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
    player[:coord].set(resp + 0.5)
    player[:login] = login
    player[:hp] = 100
    player[:weapon_angle] = -1
    @initialized = true
  end

  def next_respawn
    result = game.spawns[game.last_spawn]
    game.last_spawn = game.last_spawn + 1 == game.spawns.size ? 0 : game.last_spawn + 1
    return result
  end

  def move_position
    @wall_offset = Point(-1, -1)
    check_collisions
    return if pick_up_items_and_try_tp == "teleport"
    stop_by_collision
    player[:coord].set(player[:coord].x + (@wall_offset.x != -1 ? @wall_offset.x : player[:velocity].x),
                       player[:coord].y + (@wall_offset.y != -1 ? @wall_offset.y : player[:velocity].y))
  end

  def calc_wall_offset(wall_cell, player_new_floor_cell, player_cell, der_vectors, der)
    return if !Geometry::check_intersect(wall_cell, der_vectors)

    cell_pos = wall_cell - player_new_floor_cell
    offset = Settings.player_halfrect

    player_h_edge = Line(player_cell, Point(player_cell.x + offset * 2, player_cell.y))
    player_v_edge = Line(player_cell, Point(player_cell.x, player_cell.y + offset * 2))

    cell_h_edge = Line(wall_cell, Point(wall_cell.x + 1, wall_cell.y))
    cell_v_edge = Line(wall_cell, Point(wall_cell.x, wall_cell.y + 1))

    #сохранить смещение по Х до стенки, если она не находится над или под ячекой игрока, и если слева/справа от текущей стенки нету другой стенки,
    #и если нету пересечения проекций текущей стенки и ячейки игрока на ось Y
    if cell_pos.x != 0 && game.symbol(wall_cell.x - cell_pos.x, wall_cell.y) != WALL && !player_h_edge.prj_intersect(cell_h_edge, :x)
      @wall_offset.x = (cell_pos.x == 1 ? wall_cell.x : wall_cell.x + 1) - (player[:coord].x + offset * cell_pos.x)
    end
    if cell_pos.y != 0 && game.symbol(wall_cell.x, wall_cell.y - cell_pos.y) != WALL && !player_v_edge.prj_intersect(cell_v_edge, :y)
      @wall_offset.y = (cell_pos.y == 1 ? wall_cell.y : wall_cell.y + 1) - (player[:coord].y + offset * cell_pos.y)
    end

    bottom_left_cell = game.symbol(player_new_floor_cell.x - 1, player_new_floor_cell.y)
    bottom_right_cell = game.symbol(player_new_floor_cell.x + 1, player_new_floor_cell.y)
    #не обнулять компаненту X, если произашло столкновение с нижней левой/правой стенкой ровно в угол и нету стенок слева/стправа
    @wall_offset.x = -1 if @wall_offset.eq?(0, 0) && (der.x < 0 && bottom_left_cell != WALL || der.x > 0 && bottom_right_cell != WALL)
  end

  def check_collisions
    v_der = player[:velocity].map{|i| v_sign(i)}
    return if v_der.x == 0 && v_der.y == 0
    offset = Settings.player_halfrect
    #координаты(левая верхная точка) квадрата игрока до движения
    player_cell  = player[:coord] - offset
    #координаты ячейки в которой находится начало вектора движения игрока
    player_new_floor_cell = (player[:coord] + v_der * offset - v_der * Settings.eps).map{|i| i.floor}
    #массив векторов движения игрока
    der_vectors = Array.new()
    #движение вправо/влево или вверх/вниз
    der_vectors.push Line(player[:coord] + v_der * offset,
                          player[:coord] + v_der * offset + player[:velocity])                    if v_der.y == 0 || v_der.x == 0
    #движение влево-вверх
    der_vectors.push Line(player_cell, player_cell + player[:velocity])                           if v_der.y < 0 || v_der.x < 0
    #движение вправо-вверх
    der_vectors.push Line(Point(player_cell.x + offset * 2, player_cell.y),
                          Point(player_cell.x + offset * 2, player_cell.y) + player[:velocity])   if v_der.y < 0 || v_der.x > 0
    #движение влево-вниз
    der_vectors.push Line(Point(player_cell.x, player_cell.y + offset * 2),
                          Point(player_cell.x, player_cell.y + offset * 2) + player[:velocity])   if v_der.y > 0 || v_der.x < 0
    #движение вправо-вниз
    der_vectors.push Line(player_cell + offset * 2, player_cell + offset * 2 + player[:velocity]) if v_der.y > 0 || v_der.x > 0

    #перебор по всем стенкам вокруг player_cell
    Geometry::walk_cells_around_coord(player[:coord], player[:velocity], true) {|itr_cell|
      calc_wall_offset(itr_cell, player_new_floor_cell, player_cell, der_vectors, v_der) if game.symbol(itr_cell) == WALL
    }
  end

  def pick_up_items_and_try_tp
    tp_cell = Point(-1, -1)
    min_tp_dist = 2
    updated_velocity = Point(@wall_offset.x != -1 ? @wall_offset.x : player[:velocity].x,
                             @wall_offset.y != -1 ? @wall_offset.y : player[:velocity].y)
    Geometry::walk_cells_around_coord(player[:coord], updated_velocity, true) do |itr_cell|
      next if [VOID, WALL, RESPAWN].include?(game.symbol(itr_cell))
      cell_center = itr_cell + Settings.player_halfrect
      end_rect = player[:coord] + updated_velocity
      next if !Geometry::polygon_include_point?(player[:coord], end_rect, cell_center) ||
              Geometry::rect_include_point?(player[:coord], cell_center) ||
              min_tp_dist <= Geometry::line_len(player[:coord], cell_center)
      if ("0".."9").include?(game.symbol(itr_cell))
        v_der = player[:velocity].map{|i| v_sign(i)}
        #смещение позициии игрока по Х - на момент вертикального столкновения игрока, и по Y - на момент горизантального
        offset_to_collision = Point(v_der.y == 0 ? updated_velocity.x : player[:velocity].x * (updated_velocity.y / player[:velocity].y),
                                    v_der.x == 0 ? updated_velocity.y : player[:velocity].y * (updated_velocity.x / player[:velocity].x))
        #смещение позиции игрока на момент первого столкновения по какой-либо координате
        min_offset = Point([(offset_to_collision).x.abs, updated_velocity.x.abs].min,
                            [(offset_to_collision).y.abs, updated_velocity.y.abs].min) * v_der
        end_rect = player[:coord] + min_offset
        #если на момент первого столкновения небыло пересечения с телепортом, то занулить скорость
        stop_by_collision if !Geometry::polygon_include_point?(player[:coord], end_rect, cell_center)

        min_tp_dist = Geometry::line_len(player[:coord], cell_center)
        tp_cell = itr_cell
      elsif game.symbol(itr_cell) =~ /[a-z]/i && game.items[game.item_pos_to_idx[itr_cell.to_s]] == 0
        if game.symbol(itr_cell) == HEAL
          player[:hp] = Settings.def_game.maxHP
        elsif [GUN, MACHINE_GUN, ROCKET_LAUNCHER].include?(game.symbol(itr_cell))
          player[:weapon] = game.symbol(itr_cell)
        end

        game.items[game.item_pos_to_idx[itr_cell.to_s]] = Settings.respawn_ticks
      end
    end
    return make_tp(tp_cell) if !tp_cell.eq?(-1, -1)
  end

  def die
    player[:status] = DEAD
    player[:weapon] = KNIFE
    player[:respawn] = Settings.respawn_ticks
  end

  def get_damaged(damage)
    player[:hp] =  [player[:hp] - damage, 0].max
    die if player[:hp] == 0
  end

  def stop_by_collision
    player[:velocity].set(@wall_offset.x != -1 ? 0 : player[:velocity].x, @wall_offset.y != -1 ? 0 : player[:velocity].y)
  end

  def make_tp(coord)
    tps = game.teleports[game.symbol(coord)]
    player[:coord].set((tps[0] == coord ? tps[1] : tps[0]) + 0.5)
    "teleport"
  end

  def has_floor
    y = (player[:coord].y + Settings.player_halfrect).floor
    x1 = (player[:coord].x - Settings.player_halfrect + Settings.eps).floor
    x2 = (player[:coord].x + Settings.player_halfrect - Settings.eps).floor
    return game.symbol(x1, y) == WALL || game.symbol(x2, y) == WALL
  end

  def new_velocity(der, velocity)
    velocity.y += @consts[:gravity] if !has_floor
    if position_changed
      der = Geometry::normalize(der)
      velocity.y = -@consts[:max_velocity] if has_floor && der.y < 0
      velocity.x += der.x * @consts[:accel]
    else
      velocity.x = velocity.x.abs <= @consts[:friction] ? 0 : velocity.x - v_sign(velocity.x) * @consts[:friction]
    end
    return velocity.map{|i| [i.abs, @consts[:max_velocity]].min * v_sign(i)}
  end

  ###ACTIONS###
  def move(new_pos)
    player[:velocity] = new_velocity(new_pos, player[:velocity])
    move_position
  end

  def fire(data)
    return if ticks_after_last_fire < Settings.def_game.weapons[player[:weapon]].latency
    v = (der =Geometry::normalize(Point(data["dx"], data["dy"]))) * Settings.def_game.weapons[player[:weapon]].velocity
    projectile = {coord: player[:coord], velocity: v, owner: login, weapon: player[:weapon], ticks: 0}
    game.projectiles << projectile
    player[:weapon_angle] = Geometry::compute_angle(der)
    @ticks_after_last_fire = 0
  end
end
