module GameHelper

  def createGame(params)
    user = find_by_sid(params["sid"])
    raise BadParamsError.new(badMap) unless params["map"].kind_of?(Integer)
    find_by_id(Map, params["map"], "badMap")

    raise BadParamsError.new(alreadyInGame) unless !Player.find_by_user_id(user.id)

    def_consts = Settings.def_game_consts
    valid_consts = Proc.new{|consts|
      result = true
      def_consts.each{|name, val|
        result &&= consts[name].kind_of?(Numeric)
        result &&= consts[name] > 0 && consts[name] < 1
        result &&= consts[name] <= 0.1 if name != :maxVelocity
      }
      result
    }
    consts = !params.include?('consts') || !valid_consts.call(params['consts']) ? def_consts : params['consts']

    try_save(Game, {map_id: params["map"], user_id: user.id, name: params["name"], max_players: params["maxPlayers"],
                    accel: consts['accel'], friction: consts['friction'], max_velocity: consts['maxVelocity'], gravity: consts['gravity']})
    try_save(Player, {user_id: user.id, game_id: Game.last.id})
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
    check_error(Player.where(user_id: user.id).exists?, "alreadyInGame")

    try_save(Player, {user_id: user.id, game_id: game.id})
  end

  def leaveGame(params)
    user = find_by_sid(params["sid"])
    check_error((not (player = Player.find_by_user_id(user.id))), "notInGame")
    if (game = Game.find(player.game_id)).players.length == 1
      game.delete
    end
    player.delete
    ok
  end


end
