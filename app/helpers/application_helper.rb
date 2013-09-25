module ApplicationHelper
  def badSid
    self.response_obj = {result: "badSid"}
  end

  def badGame
    self.response_obj = {result: "badGame"}
  end

  def gameFull
    self.response_obj = {result: "gameFull"}
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
