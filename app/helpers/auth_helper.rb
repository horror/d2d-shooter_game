module AuthHelper

  def signup(params)
    params[:sid] = SecureRandom.urlsafe_base64
    try_save(User, params)
  end

  def signin(params)
    #raise BadParamsError.new(badLogin) unless params["login"].kind_of?(String)
    #raise BadParamsError.new(badPassword) unless params["password"].kind_of?(String)
    user = User.find_by_login(params["login"])
    raise BadParamsError.new(incorrect) unless user and user.authenticate(params["password"])
    user.update_attribute(:sid, SecureRandom.urlsafe_base64)
    ok({sid: user.sid})
  end

  def signout(params)
    user = find_by_sid(params["sid"])
    user.update_attribute(:sid, '')
    ok
  end

end
