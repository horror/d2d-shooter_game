module ApplicationHelper
  def badAction
    self.response_obj = {result: "badAction"}
  end

  def badSid
    self.response_obj = {result: "badSid"}
  end

  def badLogin
    self.response_obj = {result: "badLogin"}
  end

  def badPassword
    self.response_obj = {result: "badPassword"}
  end

  def userExists
    self.response_obj = {result: "userExists"}
  end

  def badGame
    self.response_obj = {result: "badGame"}
  end

  def badName
    self.response_obj = {result: "badName"}
  end

  def badExists
    self.response_obj = {result: "badExists"}
  end

  def badMaxPlayers
    self.response_obj = {result: "badMaxPlayers"}
  end

  def badMap
    self.response_obj = {result: "badMap"}
  end

  def badSince
    self.response_obj = {result: "badSince"}
  end

  def gameFull
    self.response_obj = {result: "gameFull"}
  end

  def alreadyInGame
    self.response_obj = {result: "alreadyInGame"}
  end

  def notInGame
    self.response_obj = {result: "notInGame"}
  end

  def incorrect
    self.response_obj = {result: "incorrect"}
  end

  def ok(other_params = {})
    self.response_obj = {result: "ok"}.merge(other_params)
  end

  def response_obj=(response_obj)
    @response_obj = response_obj
  end
end
