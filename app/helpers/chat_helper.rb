module ChatHelper
  def sendMessage(params)
    user = User.find_by_sid(params["sid"])
    if user
      new_message_params = {game_id: params["game"], user_id: user.id, text: params[:text]}
      message = Message.new(new_message_params)
      msg = message.save && Game.find_by_id(params["game"]) ? "ok" : "badGame"
      self.response_obj = {result: msg}
    else
      self.response_obj = {result: "badSid"}
    end
  end

  def getMessages(params)
    user = User.find_by_sid(params["sid"])
    if user
      condition = ["m.created_at > ?", params["since"]]
      if params["game"]
        if not (game = Game.find_by_id(params["game"]))
          self.response_obj = {result: "badGame"}
          return
        end
        condition = ["m.game_id = ? AND m.created_at > ?", game.id, params["since"]]
      end
      messages = Message.all(
                :select => "u.login AS login, m.text, m.created_at AS time",
                :from => 'messages m',
                :joins => "INNER JOIN users u ON m.user_id = u.id",
                :conditions => condition,
                :order => 'm.created_at desc',
      ).to_a
      self.response_obj = {result: "ok", login: user.login, message: messages}
    else
      self.response_obj = {result: "badSid"}
    end
  end
end
