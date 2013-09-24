module GameHelper
  include ErrorCodes

  def createGame
    if not (user = User.find_by_sid(params["sid"]))
      self.response_obj = {result: "badSid"}
      return
    end

    if not (map = Map.find_by_name(params["map"]))
      self.response_obj = {result: "badMap"}
      return
    end

    new_game = {map_id: map.id, user_id: user.id, name: params["name"], max_players: params["maxPlayers"]}
    game = Game.new(new_game)
    self.response_obj = game ? {result: "ok"} : {result: get_code(game.errors.full_messages.to_a.first.dup)}
  end

  def getGames

  end


end
