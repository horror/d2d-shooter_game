module MessageHelper

  def get_error_code(str)
    error_codes = {
        #signup, signin
        "Login has already been taken" => "userExists",
        "Password is too short (minimum is 4 characters)" => "badPassword",
        "Password digest can't be blank" => "badPassword",
        "Login is too short (minimum is 4 characters)" => "badLogin",
        "Login is invalid" => "badLogin",
        "Login is too long (maximum is 40 characters)" => "badLogin",
        "Login can't be blank" => "badLogin",
        #Games
        "Name can't be blank" => "badName",
        "Name has already been taken" => "gameExists",
        "Max players can't be blank" => "badMaxPlayers",
        "Max players is not a number" => "badMaxPlayers",
        "Max players must be greater than 0" => "badMaxPlayers",
        #Map
        "Map must be in game map format" => "badMap"
    }
    error_codes[str] ? error_codes[str] : str
  end

  def get_game_status(status)
    status_names = ["running", "finished"]
    status_names[status]
  end
end
