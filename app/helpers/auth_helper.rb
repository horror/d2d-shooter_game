module AuthHelper

  def signup(params)
    params[:sid] = SecureRandom.urlsafe_base64
    try_save(User, params)
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
