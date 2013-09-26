module ChatHelper

  def sendMessage(params)
    if not (user = User.find_by_sid(params["sid"]))
      badSid
      return
    end

    if params["game"] != "" and not Game.find_by_id(params["game"])
      badGame
      return
    end

    new_message_params = {game_id: params["game"] == "" ? "0" : params["game"], user_id: user.id, text: params[:text]}
    Message.create(new_message_params)
    ok
  end

  def getMessages(params)
    if not (user = User.find_by_sid(params["sid"]))
      badSid
      return
    end

    condition = ["m.created_at > ?", params["since"]]
    if params["game"] != ""
      if not (game = Game.find_by_id(params["game"]))
        badGame
        return
      end
      condition = ["m.game_id = ? AND m.created_at > ?", params["game"] == "" ? "0" : game.id, params["since"]]
    end
    messages = Message.all(
              :select => "u.login AS login, m.text, m.created_at AS time",
              :from => 'messages m',
              :joins => "INNER JOIN users u ON m.user_id = u.id",
              :conditions => condition,
              :order => 'm.created_at desc',
    ).to_a
    ok({login: user.login, messages: messages})
  end
end
