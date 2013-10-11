class BadParamsError < StandardError
end

module ValidationHelper

  def startTesting()
    ActiveRecord::Base.subclasses.each(&:delete_all)
  end

  def check_action_params(action, params)
    arr = {"startTesting" => [], "signup" => ["login", "password"], "signin" => ["login", "password"], "signout" => ["sid"],
          "sendMessage" => ["sid", "game", "text"], "getMessages" => ["sid", "game", "since"],
          "createGame" => ["sid", "name", "map", "maxPlayers"], "getGames" => ["sid"],
          "joinGame" => ["sid", "game"], "leaveGame" => ["sid"], "uploadMap" => ["sid", "name"], "getMaps" => ["sid"]}
    params_errors = {"login" => "badLogin", "password" => "badPassword", "sid" => "badSid", "game" => "badGame", "map" => "badMap",
                    "since" => "badSince", "name" => "badName", "maxPlayers" => "badMaxPlayers"}
    if !arr.include?(action) or (diff = arr[action] - params.keys).length > 0
      !arr.include?(action) ? badAction : send(params_errors[diff[0]])
      raise BadParamsError
    end
  end

  def check_error(condition, error_name)
    if (condition)
      send(error_name)
      raise BadParamsError
    end
  end

  def find_by_sid(sid)
    if (sid == "" || !(user = User.find_by_sid(sid)))
      badSid
      raise BadParamsError
    end
    return user
  end

  def find_by_id(model, id, error_name, canBeBlank = false)
    if canBeBlank and id == ""
      return
    end
    if (!(result = model.find_by_id(id)))
      send(error_name)
      raise BadParamsError
    end
    return result
  end

  def try_save(model, params)
    field = model.new(params)
    self.response_obj = field.save ? {result: "ok"} : {result: get_error_code(field.errors.full_messages.to_a.first.dup)}
  end
end
