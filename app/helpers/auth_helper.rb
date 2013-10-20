module AuthHelper

  def signup(params)
    params[:sid] = SecureRandom.urlsafe_base64
    try_save(User, params)
  end

  def signin(params)
    user = User.find_by_login(params["login"])
    if !user || !user.authenticate(params["password"])
      incorrect
      return
    end
    user.update_attribute(:sid, SecureRandom.urlsafe_base64)
    ok({sid: user.sid})
  end

  def signout(params)
    user = find_by_sid(params["sid"])

    user.update_attribute(:sid, '')
    ok
  end
end
