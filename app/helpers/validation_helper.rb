class BadParamsError < StandardError
end

module ValidationHelper

  def check_action_params(action, params)
    arr = {"startTesting" => [], "signup" => ["login", "password"], "signin" => ["login", "password"], "signout" => ["sid"],
          "sendMessage" => ["sid", "game", "text"], "getMessages" => ["sid", "game", "since"],
          "createGame" => ["sid", "name", "map", "maxPlayers"], "getGames" => ["sid"],
          "joinGame" => ["sid", "game"], "leaveGame" => ["sid"], "uploadMap" => ["name"]}
    params_errors = {"login" => "badLogin", "password" => "badPassword", "sid" => "badSid", "game" => "badGame", "map" => "badMap",
                    "since" => "badSince", "name" => "badName", "maxPlayers" => "badMaxPlayers"}
    if !arr.include?(action) or (diff = arr[action] - params.keys).length > 0
      !arr.include?(action) ? badAction : send(params_errors[diff[0]])
      raise BadParamsError
    end
  end

end
