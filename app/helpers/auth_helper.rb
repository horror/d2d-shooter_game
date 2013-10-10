module AuthHelper

  def signup(params)
    params[:sid] = SecureRandom.urlsafe_base64
    user = User.new(params)
    msg = user.save ? "ok" : get_error_code(user.errors.full_messages.to_a.first.dup)
    self.response_obj = {result: msg}
  end

  def signin(params)
    user = User.find_by_login(params["login"].downcase)
    if !user || !user.authenticate(params["password"])
      incorrect
      return
    end
    user.update_attribute(:sid, SecureRandom.urlsafe_base64)
    ok({sid: user.sid})
  end

  def signout(params)
    begin
      user = find_by_sid(params["sid"])
    rescue BadParamsError
      return
    end
    user.update_attribute(:sid, '')
    ok
  end
end
