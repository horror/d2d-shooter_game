module ApplicationHelper
  def sign_up(params)
    @user = User.new(params)
    if @user.save
      #TODO: "ok"
    else
      #TODO: кинуть ошибку
      #@user.errors.full_messages.each do |msg| end

    end
  end

  def sign_in(params)
    user = User.find_by_email(params[:email].downcase)
    if user && user.authenticate(params[:password])
      user.sid = SecureRandom.urlsafe_base64
      user.save
      self.current_user = user
      #TODO: "ok"
    else
      #TODO: кинуть ошибку
    end
  end

  def signed_in?
    !self.current_user.nil?
  end

  def current_user=(user)
    @current_user = user
  end

  def current_user
    @current_user ||= User.find_by_sid(params[:sid])
  end

  def sign_out(params)
    user = User.find_by_sid(params[:sid])
    if user
      user.sid = ''
      user.save
      #TODO: "ok"
    else
      #TODO: Кинуть ошибку
    end
  end
end
