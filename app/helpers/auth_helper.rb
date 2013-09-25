module AuthHelper
  include MessageHelper

  def signup(params)
    params[:sid] = SecureRandom.urlsafe_base64
    user = User.new(params)
    msg = user.save ? "ok" : get_error_code(user.errors.full_messages.to_a.first.dup)
    self.response_obj = {result: msg}
  end

  def signin(params)
    user = User.find_by_login(params["login"].downcase)
    if !user || !user.authenticate(params["password"])
      self.response_obj = {result: "incorrect"}
      return
    end

    user.sid = SecureRandom.urlsafe_base64
    user.save
    self.response_obj = {result: "ok", sid: user.sid}
  end

  def signout(params)

    if not (user = User.find_by_sid(params["sid"]))
      self.response_obj = {result: "badSid"}
      return
    end

    user.sid = ''
    user.save
    self.response_obj = {result: "ok"}
  end


  def response_obj=(response_obj)
    @response_obj = response_obj
  end
end
