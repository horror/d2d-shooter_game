class BadParamsError < StandardError
  def initialize(reason)
    reason.call
  end
end

module ValidationHelper

  def startTesting(params)
    ActiveRecord::Base.subclasses.each(&:delete_all)
    ok
  end

  def check_action_params(action, params)
    arr = {"startTesting" => [], "signup" => ["login", "password"], "signin" => ["login", "password"], "signout" => ["sid"],
          "sendMessage" => ["sid", "game", "text"], "getMessages" => ["sid", "game", "since"],
          "createGame" => ["sid", "name", "map", "maxPlayers"], "getGames" => ["sid"],
          "joinGame" => ["sid", "game"], "leaveGame" => ["sid"], "uploadMap" => ["sid", "name", "map", "maxPlayers"], "getMaps" => ["sid"]}

    raise BadParamsError.new(badAction) unless arr.include?(action)
    raise BadParamsError.new(badParams) unless params.is_a?(Hash) and (arr[action] - params.keys).length == 0

  end

  def check_error(condition, error_name)
    raise BadParamsError.new(Proc.new {send(error_name)}) unless !condition
  end

  def find_by_sid(sid)
    raise BadParamsError.new(badSid) unless sid != "" and user = User.find_by_sid(sid)

    return user
  end

  def find_by_id(model, id, error_name, canBeBlank = false)
    if canBeBlank and id == ""
      return
    end
    raise BadParamsError.new(Proc.new {send(error_name)}) unless result = model.find_by_id(id)

    return result
  end

  def try_save(model, params)
    m = model.new(params)
    raise BadParamsError.new(Proc.new {self.response_obj = {result: get_error_code(m.errors.full_messages.to_a.first.dup), message: m.errors.full_messages.to_a.first.dup}}) unless m.save
    ok
  end
end
