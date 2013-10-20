module GameHelper

  def createGame(params)
    user = find_by_sid(params["sid"])
    find_by_id(Map, params["map"], "badMap")

    try_save(Game, {map_id: params["map"], user_id: user.id, name: params["name"], max_players: params["maxPlayers"]})
  end

  def getGames(params)
    user = find_by_sid(params["sid"])

    games = Game.all(
        :select => "g.id, g.name, m.name AS map, g.max_players AS maxplayers, g.status, u.login AS player",
        :from => 'games g',
        :joins => "LEFT JOIN players p ON g.id = p.game_id
                  LEFT JOIN users u ON p.user_id = u.id
                  LEFT JOIN maps m ON g.map_id = m.id",
        :order => 'g.id, p.created_at'
    )
    games = games.group_by(&:id).map do
      |id, rows|
      {id: id, name: rows[0]["name"], map: rows[0]["map"], maxPlayers: rows[0]["maxplayers"].to_i,
          status: get_game_status(rows[0]["status"]), players: rows[0]["player"] == nil ? [] : rows.map{|r| r["player"]}}
    end
    ok({games: games})
  end

  def joinGame(params)
    user = find_by_sid(params["sid"])
    game = find_by_id(Game, params["game"], "badGame")
    check_error(game.players.count == game.max_players, "gameFull")
    check_error(Player.where(game_id: params["game"], user_id: user.id).exists?, "alreadyInGame")

    try_save(Player, {user_id: user.id, game_id: game.id})
  end

  def leaveGame(params)
    user = find_by_sid(params["sid"])
    check_error((not (player = Player.where(user_id: user.id)).exists?), "notInGame")

    player.delete_all
    ok
  end


end
