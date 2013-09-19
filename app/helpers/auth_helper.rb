module AuthHelper
  include ErrorCodes

  def signup(params)
    user = User.new(params)
    msg = user.save ? "ok" : get_code(user.errors.full_messages.to_a.first.dup)
    self.response_obj = {result: msg}
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
