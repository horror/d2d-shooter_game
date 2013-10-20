class Messenger
  def initialize(ws)
    @ws = ws
  end

  # запуск бесконечного цикла
  def start
    i = 0
    while self.running?
      @ws.send (i += 1).to_s
      sleep(3.seconds)
      break if i == 2
    end
  end

  # остановка мессенджера
  def stop
    @stopped = true
  end

  # запущен ли мессенджер
  def running?
    !@stopped
  end

  def send(msg)
    puts msg
  end
end