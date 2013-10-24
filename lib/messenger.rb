RESPAWN = "$"
WALL = "#"
MOVE = "move"
DEFAULT_ACCELERATION = 0.01
EPSILON = 0.0000001
ACCURACY = 6

class Messenger
  def initialize(ws)
    @ws = ws
    @to_hash = {vx: 0.0, vy: 0.0, x: 0.0, y: 0.0}
    @changed = false
    @initialized = false
  end

  # запуск бесконечного цикла
  def start
    @stopped = false
  end

  # остановка мессенджера
  def stop(ws)
    @ws != ws ? @stopped : @stopped = true
  end

  # запущен ли мессенджер
  def running?
    !@stopped
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

  def on_message(tick, players, ws = nil)
    deceleration if not changed?
    no_changes
    #puts "send: " +  ActiveSupport::JSON.encode({tick: tick, players: players.values})
    @ws.send(ActiveSupport::JSON.encode({tick: tick, players: players.values})) if players and running? and (ws.nil? or @ws == ws)
  end

  def process(data, ws, players, items)
    return if @ws != ws || !(user = User.find_by_sid(data["sid"])) || !(player = Player.find_by_user_id(user.id))
    @changed = true
    @sid ||= data["sid"]
    if !@game_id #определяем игру для клиента, если еще небыла определена
      @game_id = player.game_id
      players[game] ||= Hash.new
      players[game][@sid] = to_hash
    end

    if !@initialized #если координаты клиента не определены, находим координаты респаунов и присваеваем случайный клиенту
      @map = ActiveSupport::JSON.decode(player.game.map.map)
      @bottom_bound = (@map.size - 1).to_f + 1
      @right_bound = (@map[0].length - 1).to_f + 1
      if !items[game] #если предметы на карте в этой игре не определены, определяем их
        items[game] = Hash.new
        items[game]["respawns"] = Array.new
        items[game]["teleports"] = Hash.new
        for i in 0..@bottom_bound - 1
          for j in 0..@right_bound - 1
            case @map[i][j]
              when RESPAWN
                items[game]["respawns"] << {x: j, y: i}
              when 0..9
                items[game]["teleports"][@map[i][j].to_s] << {x: j, y: i}
            end
          end
        end
      end

      resp = items[game]["respawns"][rand(items[game]["respawns"].size)]
      set_position(resp[:x] + 0.5, resp[:y] + 0.5)
      @initialized = true
    end

    send(data["action"], data)
  end

  def set_position(x, y)
    @to_hash[:x] = x.round(ACCURACY)
    @to_hash[:y] = y.round(ACCURACY)
  end

  def move_position
    case @map[x = (@to_hash[:x] + @to_hash[:vx]).floor, y = (@to_hash[:y] + @to_hash[:vy]).floor]
      when 1..9
        make_tp(x, y)
      when WALL
        stop_movement
    end
    @to_hash[:x] += @to_hash[:vx]
    @to_hash[:y] += @to_hash[:vy]
    set_position([[0.0, @to_hash[:x]].max, @right_bound].min, [[0.0, @to_hash[:y]].max, @bottom_bound].min)
  end

  def make_tp(x, y)
    tps = items[game]["teleports"][@map[x, y]]
    tp = tps[0][:x] == x and tps[0][:y] == y ? tps[1] : tps[0]
    set_position(tp[:x], tp[:y])
  end

  def normalize(dx, dy)
    return 0, 0 if (norm = Math.sqrt(dx.to_f**2 + dy.to_f**2)) == 0.0
    dx /= norm
    dy /= norm
    return dx, dy
  end

  def change_velocity(dx, dy)
    dx, dy = normalize(dx, dy)
    @to_hash[:vx] = (@to_hash[:vx] + dx * DEFAULT_ACCELERATION).round(ACCURACY)
    @to_hash[:vy] = (@to_hash[:vy] + dy * DEFAULT_ACCELERATION).round(ACCURACY)
  end

  def stop_movement
    @to_hash[:vx] = 0.0
    @to_hash[:vy] = 0.0
  end

  def deceleration
    change_velocity(-@to_hash[:vx], -@to_hash[:vy])
    move_position
  end

  def to_hash
    @to_hash
  end

  ###ACTIONS###
  def move(data)
    change_velocity(data["dx"], data["dy"])
    move_position
  end
end