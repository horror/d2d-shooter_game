module MessageHelper
  def get_error_code(str)
    error_codes = {
        #signup, signin
        "Login has already been taken" => "userExists",
        "Password doesn't match confirmation" => "badPasswordConfirmation",
        "Password is too short (minimum is 4 characters)" => "badPassword",
        "Password digest can't be blank" => "badPassword",
        "Login is too short (minimum is 4 characters)" => "badLogin",
        "Login is invalid" => "badLogin",
        "Login is too long (maximum is 40 characters)" => "badLogin",
        "Login can't be blank" => "badLogin",
    }
    error_codes[str] ? error_codes[str] : str
  end


end
