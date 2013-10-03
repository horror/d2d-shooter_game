module GameHelper

  def createGame(params)
    if not (user = User.find_by_sid(params["sid"]))
      badSid
      return
    end
    if not (map = Map.find_by_id(params["map"]))
      badMap
      return
    end

    new_game = {map_id: params["map"], user_id: user.id, name: params["name"], max_players: params["maxPlayers"]}
    game = Game.new(new_game)
    self.response_obj = game.save ? {result: "ok"} : {result: get_error_code(game.errors.full_messages.to_a.first.dup)}
  end

  def getGames(params)
    if not (user = User.find_by_sid(params["sid"]))
      badSid
      return
    end

    games = Game.all(
        :select => "g.id, g.name, m.name AS map, g.max_players AS maxPlayers, g.status, u.login AS player",
        :from => 'games g',
        :joins => "LEFT JOIN players p ON g.id = p.game_id
                  LEFT JOIN users u ON p.user_id = u.id
                  LEFT JOIN maps m ON g.map_id = m.id",
        :order => 'g.id, p.created_at'
    )
    games = games.group_by(&:id).map do
      |id, rows|
      {id: id, name: rows[0]["name"], map: rows[0]["map"], maxPlayers: rows[0]["maxPlayers"],
          status: get_game_status(rows[0]["status"]), players: rows[0]["player"] == nil ? [] : rows.map{|r| r["player"]}}
    end
    ok({games: games})
  end

  def joinGame(params)
    if not (user = User.find_by_sid(params["sid"]))
      badSid
      return
    end

    if not (game = Game.find_by_id(params["game"]))
      badGame
      return
    end

    if game.players.count == game.max_players
      gameFull
      return
    end

    Player.create(user_id: user.id, game_id: game.id)
    self.response_obj = {result: "ok"}
  end

  def leaveGame(params)
    if not (user = User.find_by_sid(params["sid"]))
      badSid
      return
    end

    if not (player = Player.where(game_id: params["game"], user_id: user.id))
      badGame
      return
    end

    player.delete_all
  end

  def uploadMap(params)
    map = Map.create(name: params["name"])
    ok({id: map.id})
  end
end
