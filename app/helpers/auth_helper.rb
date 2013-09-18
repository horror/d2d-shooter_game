module AuthHelper

  def signup(params)
    user = User.new(params)
    self.response_obj = user.save ? {result: "ok"} : {result: "fail", message: user.errors.full_messages.to_a.join(", ")}
  end

  def signin(params)
    user = User.find_by_login(params["login"].downcase)
    if user && user.authenticate(params["password"])
      user.sid = SecureRandom.urlsafe_base64
      user.save
      #TODO: "ok"
    else
      #TODO: кинуть ошибку
    end
  end

  def response_obj=(response_obj)
    @response_obj = response_obj
  end

  def signout(params)
    user = User.find_by_sid(params["sid"])
    if user
      user.sid = ''
      user.save
      #TODO: "ok"
    else
      #TODO: Кинуть ошибку
    end
  end
end
