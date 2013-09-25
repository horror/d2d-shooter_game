module GameHelper
  include MessageHelper

  def createGame(params)
    if not (user = User.find_by_sid(params["sid"]))
      self.response_obj = {result: "badSid"}
      return
    end

    if not (map = Map.find_by_id(params["map"]))
      self.response_obj = {result: "badMap"}
      return
    end

    new_game = {map_id: map.id, user_id: user.id, name: params["name"], max_players: params["maxPlayers"]}
    game = Game.new(new_game)
    self.response_obj = game.save ? {result: "ok"} : {result: get_code(game.errors.full_messages.to_a.first.dup)}
  end

  def getGames(params)


    games = Game.all(
        :select => "g.name, g.map_id AS map, g.max_players AS maxPlayers, g.status, u.login AS player",
        :from => 'games g',
        :joins => "LEFT JOIN players p ON g.id = p.game_id
          INNER JOIN users u ON p.user_id = u.id",
        :order => 'g.id, p.created_at desc'
    )
    games = games.group_by(&:name).map do
      |name, rows|
      [name: name, map: rows[0]["map"], maxPlayers: rows[0]["maxPlayers"], status: rows[0]["status"], players: rows.map{|r| r["player"]}]
    end
    self.response_obj = {result: "ok", games: games}
  end

  def joinGame(params)
    if not (user = User.find_by_sid(params["sid"]))
      self.response_obj = {result: "badSid"}
      return
    end

    if not (game = Game.find_by_id(params["game"]))
      self.response_obj = {result: "badGame"}
      return
    end

    if game.players.count == game.max_players
      self.response_obj = {result: "gameFull"}
      return
    end

    Player.create(user_id: user.id, game_id: game.id)
    self.response_obj = {result: "ok"}
  end

  def leaveGame(params)
    if not (user = User.find_by_sid(params["sid"]))
      self.response_obj = {result: "badSid"}
      return
    end

    if not (player = Player.where(game_id: params["game"], user_id: user.id))
      self.response_obj = {result: "badGame"}
      return
    end

    player.delete_all
  end

  def uploadMap(params)
    Map.create(name: params["name"])
  end
end
