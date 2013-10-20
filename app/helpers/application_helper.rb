module ApplicationHelper
  def badAction
    resp({result: "badAction"})
  end

  def badParams
    resp({result: "badParams"})
  end

  def badJSON
    resp({result: "badJSON"})
  end

  def badSid
    resp({result: "badSid"})
  end

  def badLogin
    resp({result: "badLogin"})
  end

  def badPassword
    resp({result: "badPassword"})
  end

  def userExists
    resp({result: "userExists"})
  end

  def badGame
    resp({result: "badGame"})
  end

  def badName
    resp({result: "badName"})
  end

  def gameExists
    resp({result: "gameExists"})
  end

  def badMaxPlayers
    resp({result: "badMaxPlayers"})
  end

  def badMap
    resp({result: "badMap"})
  end

  def badSince
    resp({result: "badSince"})
  end

  def gameFull
    resp({result: "gameFull"})
  end

  def alreadyInGame
    resp({result: "alreadyInGame"})
  end

  def notInGame
    resp({result: "notInGame"})
  end

  def mapExists
    resp({result: "mapExists"})
  end

  def incorrect
    resp({result: "incorrect"})
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
