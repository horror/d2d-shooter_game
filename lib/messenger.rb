class Messenger
  def initialize(ws)
    @ws = ws
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

  def send(players, ws = nil)
    @ws.send(ActiveSupport::JSON.encode(players.values)) if running? and (ws.nil? or @ws == ws)
  end

  def process(data, ws, players)
    if @ws != ws || !(user = User.find_by_sid(data["sid"])) || !(game = Player.find_by_user_id(user.id))
      return
    end

    @sid ||= data["sid"]
    @id ||= user.id
    if !@game_id
      @game_id = game.game_id
      players[@game_id.to_s] ||= Hash.new
      players[@game_id.to_s][@sid] = to_hash
    end

  end

  def to_hash
    {sid: @sid}
  end
end

class Coords
  def initialize(x, y)
    @x = x
    @y = y
  end
end