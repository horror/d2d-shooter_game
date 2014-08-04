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

class PlayerPolygon
  attr_accessor :p1, :p2
  @poly

  def initialize(start_rect_point, end_rect_point)
    set(start_rect_point, end_rect_point)
    offset = Settings.player_halfrect - Settings.eps
    der = (p2 - p1).map{|i| f_eq(i.to_f, 0) || i.to_f > 0.0 ? 1 : -1} * offset
    @poly = [Point(p1.x - der.x, p1.y + der.y), p1 - der, Point(p1.x + der.x, p1.y - der.y),
            Point(p2.x + der.x, p2.y - der.y), p2 + der, Point(p2.x - der.x, p2.y + der.y)]
  end

  def set(start_rect_point, end_rect_point)
    @p1, @p2, = start_rect_point, end_rect_point
    self
  end
  #Проверка теоремы о разделяющих осях для полигона
  def check_SAT(shape)
    diagonal_prj_intersect = true
    if !f_eq(p1.x, p2.x) && !f_eq(p1.y, p2.y)
      #нормаль к диагональной грани полигона
      normal = Line(Point(-@poly[0].y, @poly[0].x), Point(-@poly[@poly.size - 1].y, @poly[@poly.size - 1].x))
      #вектор нормали
      normal_vector = normal.p2 - normal.p1
      #проверка пересечения проекций полигона и фигуры на вектор нормаль
      diagonal_prj_intersect = Geometry.segments_intersection(Geometry::axis_projection(normal_vector, @poly),
                                                              Geometry::axis_projection(normal_vector, shape))
    end
    diagonal_prj_intersect && Geometry::x_projections_intersect(@poly, shape) && Geometry::y_projections_intersect(@poly, shape)
  end
end

class Geometry

  def self.rect_line_intersect(wall_cell, line)
    wall_points = Geometry::cell_points(wall_cell)
    x_projections_intersect(line.points, wall_points) && y_projections_intersect(line.points, wall_points) && line.check_SAT(wall_points)
  end

  def self.walk_cells_around_coord(coord, velocity, is_rect, &block)
    v_der = velocity.map{|i| v_sign(i)}
    offset = is_rect ? Settings.player_halfrect : 0
    a_cell = (coord + v_der * offset - v_der * Settings.eps).map{|i| i.floor}

    (-1..1).each{ |i|
      (-1..1).each{ |j|
        block.call(a_cell + Point(j, i), a_cell)
      }
    }
  end

  def self.cell_points(cell)
    offset = Settings.player_halfrect
    [cell, Point(cell.x + 2 * offset, cell.y), Point(cell.x, cell.y + 2 * offset), cell + 2 * offset]
  end

  def self.segments_intersection(a, b)
    return !f_eq(a[1], b[0]) && !f_eq(a[0], b[1]) && a[1] > b[0] && b[1] > a[0]
  end

  def self.scalar_prod(p1, p2)
    p1.x * p2.x + p1.y * p2.y
  end

  def self.def_axis_projection(shape, axis_name)
    prj = [shape[0].send(axis_name), shape[0].send(axis_name)]
    shape.each{|i| prj = [[prj[0], i.send(axis_name)].min, [prj[1], i.send(axis_name)].max]}
    prj
  end

  def self.x_projections_intersect(shape_a, shape_b)
    segments_intersection(def_axis_projection(shape_a, :x), def_axis_projection(shape_b, :x))
  end

  def self.y_projections_intersect(shape_a, shape_b)
    segments_intersection(def_axis_projection(shape_a, :y), def_axis_projection(shape_b, :y))
  end

  def self.axis_projection(axis, shape_points)
    projection = [scalar_prod(axis, shape_points[0]), scalar_prod(axis, shape_points[0])]
    shape_points.each{ |i| projection = [[projection[0], scalar_prod(axis, i)].min, [projection[1], scalar_prod(axis, i)].max] }
    projection
  end

  def self.rect_include_point?(center, point)
    offset = Settings.player_halfrect - Settings.eps
    point.x > center.x - offset && point.x < center.x + offset && point.y > center.y - offset && point.y < center.y + offset
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
    (v.y < 0) ? to_degrees(Math.acos(-v.x / dist(v))) + 180 : to_degrees(Math.acos(v.x / dist(v)))
  end

  def self.normalize(der)
    return Point(0, 0) if (norm = dist(der)) == 0.0
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
    @x, @y = args[0], args[1]
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

  def scalar_prod(point)
    point.x * x + point.y * y
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
    @p1, @p2 = p1, p2
    self
  end
  #Проверка теоремы о разделяющих осях для линии
  def check_SAT(points)
    #вектор нормали линии
    normal_vector = Point(-p2.y, p2.x) - Point(-p1.y, p1.x)
    #проекции линии и фигуры на нормаль
    line_prj = Geometry::axis_projection(normal_vector, [p1, p2])
    shape_prj = Geometry::axis_projection(normal_vector, points)
    #проверка пересечения проекций
    Geometry.segments_intersection(line_prj, shape_prj)
  end

  def points
    [@p1, @p2]
  end
end

def Point(x, y)
  Point.new(x, y)
end

def Line(p1, p2)
  Line.new(p1, p2)
end

def PlayerPolygon(p1, p2)
  PlayerPolygon.new(p1, p2)
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
        p[:weapon], p[:weapon_angle].to_i, p[:login], p[:hp], p[:respawn], p[:kills], p[:deaths]
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
    min_dist = 2
    begin
      new_coord = old_coord + v_der
      der = Line(old_coord, new_coord)
      Geometry::walk_cells_around_coord(old_coord, v_der, false) {|itr_cell|
        next if symbol(itr_cell) != WALL || !Geometry::rect_line_intersect(itr_cell, der)
        intersected = true
        min_dist = [min_dist, Geometry::line_len(old_coord, itr_cell + Settings.player_halfrect)].min
      }

      clients.each do |c_sid, client|
        c_player = client.player
        player_cell = c_player[:coord] - Settings.player_halfrect
        next if min_dist < Geometry::line_len(c_player[:coord], old_coord)
        if client.login != projectile[:owner].login && c_player[:status] == ALIVE && Geometry::rect_line_intersect(player_cell, der)
          projectile[:owner].do_damage(client, dm)
          intersected = true
          break
        end
      end
      old_coord = new_coord
    end until (intersected || projectile[:weapon] != RAIL_GUN)

    projectile[:coord] = new_coord if projectile[:weapon] != RAIL_GUN
    projectile[:velocity] = new_coord - projectile[:coord] if projectile[:weapon] == RAIL_GUN
    damage_players_on_area(projectile[:owner], new_coord, r, dm) if projectile[:weapon] == ROCKET_LAUNCHER && intersected
    intersected
  end

  def damage_players_on_area(player, center, radius, damage)
    clients.each do |c_sid, client|
      c_player = client.player
      if c_player[:status] == ALIVE && Geometry::line_len(center, c_player[:coord]) <= radius
        player.do_damage(client, damage)
        der = Geometry::normalize(c_player[:coord] - center)
        if client.player[:status] == ALIVE
          client.player[:velocity] = der * Settings.def_game.consts.maxVelocity
          client.move_position
        end
      end
    end
  end

  def move_projectiles
    projectiles.delete_if do |projectile|
      need_delete = projectile[:velocity] == Point.new(0, 0) ||
          (projectile[:weapon] == RAIL_GUN && projectile[:ticks] != 0 || projectile_intersects?(projectile))
      need_delete = false if projectile[:weapon] == RAIL_GUN && projectile[:ticks] == 0
      projectile[:ticks] += 1
      projectile[:velocity] = Point.new(0, 0) if [KNIFE].include?(projectile[:weapon])
      if need_delete && projectile[:velocity] != Point.new(0, 0)
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

  def save_stats
    clients.each do |c_sid, client|
      Stat.find_or_initialize_by_user_id_and_game_id(client.id, id).update_attributes({
        kills: client.player[:kills],
        deaths: client.player[:deaths],
      })
    end
  end
end

class Client

  attr_accessor :ws, :sid, :id, :login, :game_id, :games, :player, :summed_move_params, :position_changed, :answered, :ticks_after_last_fire

  def initialize(ws, games)
    @player = {velocity: Point(0.0, 0.0), coord: Point(0.0, 0.0), hp: Settings.def_game.maxHP, status: ALIVE, respawn: 0, weapon: KNIFE, kills: 0, deaths: 0}
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
    response = {tick: tick, players: game.get_players, projectiles: game.get_projectiles, items: game.get_items}
    ws.send(ActiveSupport::JSON.encode(response)) if game
  end

  def process(data, tick)
    params = data['params']

    return if !(user = User.find_by_sid(params["sid"])) ||
        !(player_model = Player.find_by_user_id(user.id)) ||
        (@initialized && tick - Settings.tickDeleayRange > params['tick'])
    @answered = true
    return if data["action"] == "empty"
    @id ||= user.id
    @login ||= user.login
    @game_id ||= player_model.game_id
    @sid ||= params["sid"]
    @consts = {accel: player_model.game.accel, max_velocity: player_model.game.max_velocity,
               friction: player_model.game.friction, gravity: player_model.game.gravity}
    games[game_id] = ActiveGame.new(game_id, player_model.game.map.map) if !@games.include?(game_id)

    if !@initialized
      init_player if !try_load_player
      load_stats
      game.clients[sid] = self
    end

    return if player[:status] == DEAD
    if data["action"] == MOVE
      return if f_eq(params["dx"], 0) && f_eq(params["dy"], 0)
      summed_move_params.x += params["dx"].to_f
      summed_move_params.y += params["dy"].to_f
      @position_changed = true if !f_eq(params["dx"], 0)
    else
      send(data["action"], params)
    end
  end

  def try_load_player
    finded = false
    game.clients.each{ |sid, client|
      if sid == @sid
        @player = client.player
        client.answered = true
        @initialized = true
        finded = true
        break
      end
    }
    finded
  end

  def init_player
    resp = next_respawn
    player[:coord].set(resp + 0.5)
    player[:weapon] = KNIFE
    player[:login] = login
    player[:hp] = Settings.def_game.maxHP
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

  def calc_wall_offset(wall_cell, center_cell, coord, v_der, wall_offset)
    offset = Settings.player_halfrect
    wall_pos = wall_cell - center_cell
    player_h_edge = Line(coord - offset, Point(coord.x + offset, coord.y - offset))
    player_v_edge = Line(coord - offset, Point(coord.x - offset, coord.y + offset))

    cell_h_edge = Line(wall_cell, Point(wall_cell.x + 1, wall_cell.y))
    cell_v_edge = Line(wall_cell, Point(wall_cell.x, wall_cell.y + 1))

    #сохранить смещение по Х до стенки, если она не находится над или под ячекой игрока, и если слева/справа от текущей стенки нету другой стенки,
    #и если нету пересечения проекций текущей стенки и ячейки игрока на ось X
    if wall_pos.x != 0 && game.symbol(wall_cell.x - wall_pos.x, wall_cell.y) != WALL && !Geometry::x_projections_intersect(player_h_edge.points, cell_h_edge.points)
      wall_offset.x = (wall_pos.x == 1 ? wall_cell.x : wall_cell.x + 1) - (coord.x + offset * wall_pos.x)
    end
    if wall_pos.y != 0 && game.symbol(wall_cell.x, wall_cell.y - wall_pos.y) != WALL && !Geometry::y_projections_intersect(player_v_edge.points, cell_v_edge.points)
      wall_offset.y = (wall_pos.y == 1 ? wall_cell.y : wall_cell.y + 1) - (coord.y + offset * wall_pos.y)
    end

    left_cell = game.symbol(center_cell.x - 1, center_cell.y)
    right_cell = game.symbol(center_cell.x + 1, center_cell.y)
    #не обнулять компаненту X, если произашло столкновение с нижней левой/правой стенкой ровно в угол и нету стенок слева/стправа
    wall_offset.x = -1 if wall_offset.eq?(0, 0) && (v_der.x < 0 && left_cell != WALL || v_der.x > 0 && right_cell != WALL)
  end

  def check_collisions
    return if player[:velocity].eq?(0, 0)
    v_der = player[:velocity].map{|i| v_sign(i)}
    player_polygon = PlayerPolygon(player[:coord], player[:coord] + player[:velocity])
    Geometry::walk_cells_around_coord(player[:coord], player[:velocity], true) {|itr_cell, center_cell|
      next if game.symbol(itr_cell) != WALL || !player_polygon.check_SAT(Geometry::cell_points(itr_cell))
      calc_wall_offset(itr_cell, center_cell, player[:coord], v_der, @wall_offset)
    }
  end

  def pick_up_items_and_try_tp
    tp_cell = Point(-1, -1)
    min_tp_dist = 2
    updated_velocity = Point(@wall_offset.x != -1 ? @wall_offset.x : player[:velocity].x,
                             @wall_offset.y != -1 ? @wall_offset.y : player[:velocity].y)
    end_rect = player[:coord] + updated_velocity
    playerPoly = PlayerPolygon(player[:coord], end_rect)
    Geometry::walk_cells_around_coord(player[:coord], updated_velocity, true) do |itr_cell|
      cell_center = itr_cell + Settings.player_halfrect
      next if !("0".."9").include?(game.symbol(itr_cell)) ||
              !playerPoly.check_SAT([cell_center]) ||
              Geometry::rect_include_point?(player[:coord], cell_center) ||
              min_tp_dist <= Geometry::line_len(player[:coord], cell_center)

      v_der = player[:velocity].map{|i| v_sign(i)}
      #смещение позициии игрока по Х - на момент вертикального столкновения игрока, и по Y - на момент горизантального
      offset_to_collision = Point(v_der.y == 0 ? updated_velocity.x : player[:velocity].x * (updated_velocity.y / player[:velocity].y),
                                  v_der.x == 0 ? updated_velocity.y : player[:velocity].y * (updated_velocity.x / player[:velocity].x))
      #смещение позиции игрока на момент первого столкновения по какой-либо координате
      min_offset = Point([(offset_to_collision).x.abs, updated_velocity.x.abs].min,
                          [(offset_to_collision).y.abs, updated_velocity.y.abs].min) * v_der
      end_rect = player[:coord] + min_offset
      #если на момент первого столкновения небыло пересечения с телепортом, то занулить скорость
      stop_by_collision if !PlayerPolygon(player[:coord], end_rect).check_SAT([cell_center])

      min_tp_dist = Geometry::line_len(player[:coord], cell_center)
      tp_cell = itr_cell
    end
    Geometry::walk_cells_around_coord(player[:coord], updated_velocity, true) do |itr_cell|
      cell_center = itr_cell + Settings.player_halfrect
      next if !(game.symbol(itr_cell) =~ /[a-z]/i && game.items[game.item_pos_to_idx[itr_cell.to_s]] == 0) ||
              !playerPoly.check_SAT([cell_center]) ||
              Geometry::rect_include_point?(player[:coord], cell_center) ||
              min_tp_dist <= Geometry::line_len(player[:coord], cell_center)
      if game.symbol(itr_cell) == HEAL
        player[:hp] = Settings.def_game.healRegen
      elsif [GUN, MACHINE_GUN, ROCKET_LAUNCHER, RAIL_GUN, KNIFE].include?(game.symbol(itr_cell))
        player[:weapon] = game.symbol(itr_cell)
      end
      game.items[game.item_pos_to_idx[itr_cell.to_s]] = Settings.respawn_ticks
    end

    return make_tp(tp_cell) if !tp_cell.eq?(-1, -1)
  end

  def die
    player[:status] = DEAD
    player[:deaths] += 1
    player[:respawn] = Settings.respawn_ticks
  end

  def get_damaged(damage)
    player[:hp] = [player[:hp] - damage, 0].max
    die if player[:hp] == 0
    player[:hp] == 0
  end

  def do_damage(enemy, damage)
    player[:kills] += 1 if enemy.get_damaged(damage) && enemy.login != login
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
    velocity.y = -@consts[:max_velocity] if has_floor && der.y < 0 && !f_eq(der.y, 0)
    if position_changed
      der = Geometry::normalize(der)
      velocity.x += v_sign(der.x) * @consts[:accel]
    else
      velocity.x = velocity.x.abs <= @consts[:friction] ? 0 : velocity.x - v_sign(velocity.x) * @consts[:friction]
    end
    return velocity.map{|i| [i.abs, @consts[:max_velocity]].min * v_sign(i)}
  end

  def load_stats
    if (s = Stat.find_by_user_id_and_game_id(id, game_id))
      player[:kills] = s.kills
      player[:deaths] = s.deaths
    end
  end

  ###ACTIONS###
  def move(new_pos)
    return if player[:status] == DEAD
    player[:velocity] = new_velocity(new_pos, player[:velocity])
    move_position
  end

  def fire(data)
    return if ticks_after_last_fire < Settings.def_game.weapons[player[:weapon]].latency
    v = (der =Geometry::normalize(Point(data["dx"], data["dy"]))) * Settings.def_game.weapons[player[:weapon]].velocity
    projectile = {coord: player[:coord], velocity: v, owner: self, weapon: player[:weapon], ticks: 0}
    game.projectiles << projectile
    player[:weapon_angle] = Geometry::compute_angle(der)
    @ticks_after_last_fire = 0
  end
end
