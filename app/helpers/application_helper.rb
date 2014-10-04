# coding: utf-8
module ApplicationHelper
  def badAction
    resp({result: "badAction"})
  end

  def badRequest
    resp({result: "badRequest"})
  end

  def badJSON
    resp({result: "badJSON"})
  end

  def badSid
    resp({result: "badSid", message: "Неверный sid"})
  end

  def badLogin
    resp({result: "badLogin", message: "Логин должен состоять минимум из одной буквы и цифр(мин. 4 символа)"})
  end

  def badPassword
    resp({result: "badPassword", message: "Пароль должен состоять минимум из одной буквы и цифр(мин. 4 символа)"})
  end

  def userExists
    resp({result: "userExists", message: "Пользователь с таким ником уже зарегистрирован"})
  end

  def badGame
    resp({result: "badGame", message: "Такой игры не существует"})
  end

  def badName
    resp({result: "badName"})
  end

  def gameExists
    resp({result: "gameExists", message: "Игра с таким именем уже существует"})
  end

  def badMaxPlayers
    resp({result: "badMaxPlayers"})
  end

  def badMap
    resp({result: "badMap", message: "Такой карты не существует"})
  end

  def badText
    resp({result: "badText"})
  end

  def badSince
    resp({result: "badSince"})
  end

  def gameFull
    resp({result: "gameFull", message: "Игра заполнена, выберите другию или создайте свою"})
  end

  def gameRunning
    resp({result: "gameRunning", message: "Вы не можите посмотреть статистику сейчас"})
  end

  def gameFinished
    resp({result: "gameFinished", message: "Игра закончена"})
  end

  def alreadyInGame
    resp({result: "alreadyInGame", message: "Вы уже играете"})
  end

  def notInGame
    resp({result: "notInGame", message: "Вы не играете в этой игре"})
  end

  def mapExists
    resp({result: "mapExists", message: "Карта с таким именем уже существует" })
  end

  def incorrect
    resp({result: "incorrect", message: "Неверная комбинация логин и пароль"})
  end

  def ok(other_params = {})
    resp({result: "ok"}.merge(other_params))
  end

  def resp(response)
    self.response_obj = response;
  end

  def response_obj=(response_obj)
    @response_obj = response_obj
  end
end
