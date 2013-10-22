RESPAWN = "$"
WALL = "#"
MOVE = "move"
DEFAULT_ACCELERATION = 5

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

  def on_message(players, ws = nil)
    deceleration if not changed?
    no_changes
    @ws.send(ActiveSupport::JSON.encode(players.values)) if players and running? and (ws.nil? or @ws == ws)
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
      if !items[game] #если предметы на карте в этой игре не определены, определяем их
        items[game] = Hash.new
        items[game]["respawns"] = Array.new
        items[game]["walls"] = Array.new
        map = ActiveSupport::JSON.decode(player.game.map.map)
        @bottom_bound = (map.size - 1).to_f
        @left_bound = (map[0].length - 1).to_f
        for i in 0..@bottom_bound
          for j in 0..@left_bound
            case map[i][j]
              when RESPAWN
                items[game]["respawns"] << Geometry::Point[j, i]
            end
          end
        end
      end

      resp = items[game]["respawns"][rand(items[game]["respawns"].size)]
      set_position(resp.x, resp.y)
      @initialized = true
    end

    send(data["action"], data)
  end

  def set_position(x, y)
    @to_hash[:x] = x
    @to_hash[:y] = y
  end

  def move_position
    @to_hash[:x] += @to_hash[:vx]
    @to_hash[:y] += @to_hash[:vy]
    set_position([[0.0, @to_hash[:x]].max, @left_bound].min, [[0.0, @to_hash[:y]].max, @bottom_bound].min)
  end

  def normalize(dx, dy)
    if (max = [dx.to_f.abs, dy.to_f.abs].max) != 0.0
      dx /= max
      dy /= max
    end
    return dx, dy
  end

  def change_velocity(dx, dy)
    dx, dy = normalize(dx, dy)
    @to_hash[:vx] += dx * DEFAULT_ACCELERATION
    @to_hash[:vy] += dy * DEFAULT_ACCELERATION
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