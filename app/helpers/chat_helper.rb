module ChatHelper

  def sendMessage(params)
    begin
      user = find_by_sid(params["sid"])
      find_by_id(Game, params["game"], "badGame", true)
    rescue BadParamsError
      return
    end

    new_message_params = {game_id: params["game"] == "" ? "0" : params["game"], user_id: user.id, text: params[:text]}
    Message.create(new_message_params)
    ok
  end

  def getMessages(params)
    begin
      user = find_by_sid(params["sid"])
      game = find_by_id(Game, params["game"], "badGame", true)
      since = Time.at(params["since"]).to_i
    rescue BadParamsError
      return
    rescue
      badSince
      return
    end
    condition =  params["game"] == "" ? ["time > ?", since] : ["m.created_at > ? AND m.game_id = ?", since, game.id]

    messages = Message.all(
              :select => "u.login AS login, m.text, CAST(strftime('%s', m.created_at) AS int) AS time",
              :from => 'messages m',
              :joins => "INNER JOIN users u ON m.user_id = u.id",
              :conditions => condition,
              :order => 'm.created_at desc',
    ).to_a
    ok({messages: messages})
  end
end
