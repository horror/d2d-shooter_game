RESPAWN = "$"
MOVE = "move"

class Messenger
  def initialize(ws)
    @ws = ws
    @to_hash = Hash.new
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

  def game
    (@game_id ? @game_id : 0).to_s
  end

  def sid
    @sid
  end

  def on_message(players, ws = nil)
    @ws.send(ActiveSupport::JSON.encode(players.values)) if players and running? and (ws.nil? or @ws == ws)
  end

  def process(data, ws, players, items)
    return if @ws != ws || !(user = User.find_by_sid(data["sid"])) || !(player = Player.find_by_user_id(user.id))

    @sid ||= data["sid"]
    if !@game_id #определяем игру для клиента, если еще небыла определена
      @game_id = player.game_id
      players[game] ||= Hash.new
      players[game][@sid] = to_hash
    end

    if !@to_hash[:x] #если координаты клиента не определены, находим координаты респаунов и присваеваем случайный клиенту
      if !items[game] #если предметы на карте в этой игре не определены, определяем их
        items[game] = Hash.new
        items[game]["respawns"] = Array.new
        map = ActiveSupport::JSON.decode(player.game.map.map)

        for i in 0..(map.size - 1)
          for j in 0..(map[0].length - 1)
            case map[i][j]
              when RESPAWN
                items[game]["respawns"] << {x: j, y: i}
            end
          end
        end
      end

      resp = items[game]["respawns"][rand(items[game]["respawns"].size)]
      set_coords(resp[:x], resp[:y])
    end

    send(data["action"], data)
  end

  def set_coords(x, y)
    @to_hash[:x] = x
    @to_hash[:y] = y
  end

  def move_coords(dx, dy)
    @to_hash[:x] += dx
    @to_hash[:y] += dy
  end

  def to_hash
    @to_hash
  end

  ###ACTIONS###
  def move(data)
    move_coords(data["dx"], data["dy"])
  end
end