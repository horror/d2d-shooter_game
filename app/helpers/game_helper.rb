module GameHelper

  def createGame(params)
    begin
      user = find_by_sid(params["sid"])
      find_by_id(Map, params["map"], "badMap")
    rescue BadParamsError
      return
    end

    new_game = {map_id: params["map"], user_id: user.id, name: params["name"], max_players: params["maxPlayers"]}
    game = Game.new(new_game)
    self.response_obj = game.save ? {result: "ok"} : {result: get_error_code(game.errors.full_messages.to_a.first.dup)}
  end

  def getGames(params)
    begin
      user = find_by_sid(params["sid"])
    rescue BadParamsError
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
    begin
      user = find_by_sid(params["sid"])
      game = find_by_id(Game, params["game"], "badGame")
      check_error(game.players.count == game.max_players, "gameFull")
      check_error(Player.where(game_id: params["game"], user_id: user.id).exists?, "alreadyInGame")
    rescue BadParamsError
      return
    end

    player = Player.create(user_id: user.id, game_id: game.id)
    self.response_obj = player.save ? {result: "ok"} : {result: get_error_code(player.errors.full_messages.to_a.first.dup)}
  end

  def leaveGame(params)
    begin
      user = find_by_sid(params["sid"])
      check_error((not (player = Player.where(user_id: user.id)).exists?), "notInGame")
    rescue BadParamsError
      return
    end
    player.delete_all
    ok
  end

  def uploadMap(params)
    begin
      user = find_by_sid(params["sid"])
      check_error(Map.where(name: params["name"]).exists?, "mapExists")
    rescue BadParamsError
      return
    end
    map = Map.new(name: params["name"])
    self.response_obj = map.save ? {result: "ok"} : {result: get_error_code(map.errors.full_messages.to_a.first.dup)}
  end

  def getMaps(params)
    begin
      user = find_by_sid(params["sid"])
    rescue BadParamsError
      return
    end
    maps = Map.all(:select => "m.id, m.name", :from => 'maps m', :order => 'm.id').to_a
    ok({maps: maps})
  end
end
