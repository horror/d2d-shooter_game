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
    resp({result: "badSid", message: "This sicret ID wrong"})
  end

  def badLogin
    resp({result: "badLogin", message: "Username must meet format"})
  end

  def badPassword
    resp({result: "badPassword", message: "Password must meet format"})
  end

  def userExists
    resp({result: "userExists", message: "User with this name already exists"})
  end

  def badGame
    resp({result: "badGame", message: "This game doesn't exists"})
  end

  def badName
    resp({result: "badName"})
  end

  def gameExists
    resp({result: "gameExists", message: "Game with this name already exists"})
  end

  def badMaxPlayers
    resp({result: "badMaxPlayers"})
  end

  def badMap
    resp({result: "badMap", message: "This map doesn't exists"})
  end

  def badText
    resp({result: "badText"})
  end

  def badSince
    resp({result: "badSince"})
  end

  def gameFull
    resp({result: "gameFull", message: "This game full"})
  end

  def alreadyInGame
    resp({result: "alreadyInGame", message: "U already playing"})
  end

  def notInGame
    resp({result: "notInGame", message: "U are not playing in this game"})
  end

  def mapExists
    resp({result: "mapExists", message: "Map with this name already exists" })
  end

  def incorrect
    resp({result: "incorrect", message: "Combination name and password incorrect"})
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
