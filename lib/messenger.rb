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

  def send(msg, ws = nil)
    @ws.send @sid if @sid and running? and (ws.nil? or @ws == ws)
  end

  def process(data, ws)
    return if @ws != ws
    @sid ||= data["sid"]
    @id ||= User.where(sid: data[:sid]).first
    @game_id ||= Player.where(user_id: @id)
  end
end

class Coords
  def initialize(x, y)
    @x = x
    @y = y
  end
end