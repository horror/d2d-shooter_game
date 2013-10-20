module ChatHelper

  def sendMessage(params)
    user = find_by_sid(params["sid"])
    find_by_id(Game, params["game"], "badGame", true)

    try_save(Message, {game_id: params["game"], user_id: user.id, text: params[:text]})
  end

  def getMessages(params)

    user = find_by_sid(params["sid"])
    game = find_by_id(Game, params["game"], "badGame", true)

    begin
      Time.at(params["since"]).to_i
    rescue
      raise BadParamsError.new(badSince)
    end

    messages = Message.
        select("u.login AS login, m.text, extract(epoch from m.created_at)::int AS time").
        from("messages m").
        joins("INNER JOIN users u ON m.user_id = u.id").
        where("extract(epoch from m.created_at)::int > ?", params["since"]).
        where("m.game_id" => params["game"] == "" ? nil : game.id).
        order("m.created_at desc").to_a
    ok({messages: messages})
  end
end
