require "spec_helper"
require "date"
require 'rest_client'

describe "Application page" do
  map_id = game_a = game_b = sid_c = sid_b = sid_a = 0

  before(:all) do
    request_and_checking("startTesting", {websocketMode: "async"})
  end

  describe "bad json" do
    it "#1" do
      send_request_json("[")
      check_response({result: "badJSON"}, "200")
    end

    it "#2" do
      send_request_json("")
      check_response({result: "badJSON"}, "200")
    end
  end

  describe "bad action" do
    it "without action" do
      request_and_checking("", {}, {result: "badAction"})
    end

    it "non-existent action" do
      request_and_checking("someAction", {}, {result: "badAction"})
    end
  end

  describe "sign up" do
    def check_it(params, result = "ok")
      request_and_checking("signup", params, {result: result})
    end

    it "with invalid login(not sended)" do
      check_it({password: "lololol"}, "badRequest")
    end

    it "with invalid password(not sended)" do
      check_it({login: "vas"}, "badRequest")
    end

    it "with valid information" do
      check_it({login: "user_a", password: "lololol"})
    end

    it "with valid information (case sensitivity)" do
      check_it({login: "user_A", password: "lololol"})
    end

    it "with invalid information(userExists)" do
      check_it({login: "user_a", password: "lololol"}, "userExists")
    end

    it "with invalid information(too short login)" do
      check_it({login: "vas", password: "lololol"}, "badLogin")
    end

    it "with invalid information(blank login)" do
      check_it({login: "", password: "lololol"}, "badLogin")
    end

    it "with invalid information(too long login)" do
      check_it({login: "a" * 41, password: "lololol"}, "badLogin")
    end

    it "with invalid information(invalid characters in login)" do
      check_it({login: '$%#@@$%%^', password: "lololol"}, "badLogin")
    end

    it "with invalid information(too short password)" do
      check_it({login: "vasssya", password: "lol"}, "badPassword")
    end

    it "with invalid information(blank password)" do
      check_it({login: "vasssya", password: ""}, "badPassword")
    end

  end

  describe "sign in" do
    it "with invalid login(not sended)" do
      request_and_checking("signin", {password: "lololol"}, {result: "badRequest"})
    end

    it "with invalid password(not sended)" do
      request_and_checking("signin", {login: "vas"}, {result: "badRequest"})
    end

    it "with invalid information(not string login)" do
      request_and_checking("signin", {login: {sstring: "asasasas"}, password: "lololol"}, {result: "badLogin"})
    end

    it "with invalid information(not string pass)" do
      request_and_checking("signin", {login: "user_a", password: {string: "asasasas"}}, {result: "badPassword"})
    end

    it "with valid information" do
      send_request(action: "signin", params:{login: "user_a", password: "lololol"})
      response.code.to_s.should == "200" && json_decode(response.body)["result"].should == "ok"
    end

    it "with invalid information(incorrect login)" do
      request_and_checking("signin", {login: "error_login", password: "lololol"}, {result: "incorrect"})
    end

    it "with invalid information(incorrect password)" do
      request_and_checking("signin", {login: "user_a", password: "error_pass"}, {result: "incorrect"})
    end
  end

  describe "sign out" do
    before do
      send_request(action: "signin", params:{login: "user_a", password: "lololol"})
      sid_a = json_decode(response.body)["sid"]
    end

    it "with invalid sid(not sended)" do
      request_and_checking("signout", {}, {result: "badRequest"})
    end

    it "with invalid information(badSid)" do
      request_and_checking("signout", {sid: "100500"}, {result: "badSid"})
    end

    it "with valid information" do
      request_and_checking("signout", {sid: sid_a})
    end

    it "double singout" do
      send_request(action: "signout", params:{sid: sid_a})
      request_and_checking("signout", {sid: sid_a}, {result: "badSid"})
    end

    after(:all) do
      send_request(action: "signin", params:{login: "user_a", password: "lololol"})
      sid_a = json_decode(response.body)["sid"]
      send_request(action: "signup", params:{login: "user_b", password: "lololol"})
      send_request(action: "signin", params:{login: "user_b", password: "lololol"})
      sid_b = json_decode(response.body)["sid"]
    end
  end

  describe "upload map" do
    def check_it(params, result = "ok")
      request_and_checking("uploadMap", params, {result: result})
    end

    it "with invalid user sid(not sended)" do
      check_it({name: "New map"}, "badRequest")
    end

    it "with invalid user name(not sended)" do
      check_it({sid: sid_a}, "badRequest")
    end

    it "with valid information" do
      check_it({sid: sid_a, name: "New map", maxPlayers: 11, map: ["#19d", "z.#5", "$4$#"]})
    end

    it "with invalid name(max exists)" do
      check_it({sid: sid_a, name: "New map", maxPlayers: 11, map: ["####", "####", "####"]}, "mapExists")
    end

    it "with invalid name(blank)" do
      check_it({sid: sid_a, name: "", maxPlayers: 11, map: ["####", "####", "####"]}, "badName")
    end

    it "with invalid map(diff lines length)" do
      check_it({sid: sid_a, name: "sdfadsfadf", maxPlayers: 11, map: ["##", "####", "###"]}, "badMap")
    end

    it "with invalid map(unexpected symbol #1)" do
      check_it({sid: sid_a, name: "sdafadsfdsafads", maxPlayers: 11, map: ["##%#", "####", "####"]}, "badMap")
    end

    it "with invalid map(unexpected symbol #2)" do
      check_it({sid: sid_a, name: "adsfadsfasfdsaf", maxPlayers: 11, map: ["####", "#+##", "####"]}, "badMap")
    end

    it "with invalid map(unexpected symbol #3)" do
      check_it({sid: sid_a, name: "sdfadsdafafds", maxPlayers: 11, map: ["####", "####", "##}#"]}, "badMap")
    end

    it "with invalid map(not array)" do
      check_it({sid: sid_a, name: "sdfadsdafafds", maxPlayers: 11, map: "dsa"}, "badMap")
    end

    it "with invalid map(not array #2)" do
      check_it({sid: sid_a, name: "sdfadsdafafds", maxPlayers: 11, map: {"dsa" => "sddsdf"}}, "badMap")
    end

    it "with invalid maxPlayers (< 1)" do
      check_it({sid: sid_a, name: "New game1", map: ["####", "####", "####"], maxPlayers: 0}, "badMaxPlayers")
    end

    it "with invalid maxPlayers (blank)" do
      check_it({sid: sid_a, name: "New game1", map: ["####", "####", "####"], maxPlayers: ""}, "badMaxPlayers")
    end

    it "with invalid maxPlayers (is not a number)" do
      check_it({sid: sid_a, name: "New game1", map: ["####", "####", "####"], maxPlayers: "sda"}, "badMaxPlayers")
    end
  end

  describe "get maps" do
    it "with invalid user sid(not sended)" do
      request_and_checking("getMaps", {}, {result: "badRequest"})
    end

    it "with valid information" do
      send_request(action: "getMaps", params:{sid: sid_a})
      arr = json_decode(response.body)
      map_id = arr["maps"][0]["id"]
      response.code.to_s.should == "200"  && arr["maps"].length == 1 && arr["maps"][0]["name"].should == "New map" &&
          arr["maps"][0]["maxPlayers"].should == 11 && arr["maps"][0]["map"].should == ["#19d", "z.#5", "$4$#"]
    end

    it "with invalid user sid" do
      request_and_checking("getMaps", {sid: ""}, {result: "badSid"})
    end
  end

  describe "create game" do
    def check_it(params, result = "ok")
      request_and_checking("createGame", params, {result: result})
    end

    it "with invalid user sid(not sended)" do
      check_it({name: "New game1", map: map_id, maxPlayers: 10}, "badRequest")
    end

    it "with invalid map id(not sended)" do
      check_it({sid: sid_a, name: "New game1", maxPlayers: 10}, "badRequest")
    end

    it "with invalid name (not sended)" do
      check_it({sid: sid_a, map: map_id, maxPlayers: 10}, "badRequest")
    end

    it "with invalid maxPlayers (not sended)" do
      check_it({sid: sid_a, name: "New game1", map: map_id}, "badRequest")
    end

    it "with valid information" do
      check_it({sid: sid_a, name: "New game", map: map_id, maxPlayers: 3})
    end

    it "with user in already game" do
      check_it({sid: sid_a, name: "New game 2", map: map_id, maxPlayers: 3}, "alreadyInGame")
    end

    it "with exist name" do
      check_it({sid: sid_b, name: "New game", map: map_id, maxPlayers: 10}, "gameExists")
    end

    it "with invalid user sid" do
      check_it({sid: "100500", name: "New game1", map: map_id, maxPlayers: 10}, "badSid")
    end

    it "with invalid map id" do
      check_it({sid: sid_b, name: "New game1", map: 100500, maxPlayers: 10}, "badMap")
    end

    it "with invalid name (blank)" do
      check_it({sid: sid_b, name: "", map: map_id, maxPlayers: 10}, "badName")
    end

    it "with invalid maxPlayers (< 1)" do
      check_it({sid: sid_b, name: "New game1", map: map_id, maxPlayers: 0}, "badMaxPlayers")
    end

    it "with invalid maxPlayers (> maxPlayers in map)" do
      check_it({sid: sid_b, name: "New game1", map: map_id, maxPlayers: 18}, "badMaxPlayers")
    end

    it "with invalid maxPlayers (blank)" do
      check_it({sid: sid_b, name: "New game1", map: map_id, maxPlayers: ""}, "badMaxPlayers")
    end

    it "with invalid maxPlayers (is not a number)" do
      check_it({sid: sid_b, name: "New game1", map: map_id, maxPlayers: "sda"}, "badMaxPlayers")
    end
  end

  describe "get games" do
    before(:all) do
      send_request(action: "createGame", params: {sid: sid_b, name: "New game 2", map: map_id, maxPlayers: 10})
      @check_arr = [{"name" => "New game", "map" => "New map", "maxPlayers" => 1, "status" => "running", "players" => ["user_a"]},
                    {"name" => "New game 2", "map" => "New map", "maxPlayers" => 10, "status" => "running", "players" => ["user_b"]}]
    end

    it "with invalid sid(not sended)" do
      request_and_checking("getGames", {}, {result: "badRequest"})
    end

    it "with valid information" do
      send_request(action: "getGames", params: {sid: sid_a})
      arr = json_decode(response.body)
      result = arr["result"] == "ok"
      game_a = arr["games"][0]["id"]
      game_b = arr["games"][1]["id"]
      arr["games"].each_with_index do |element, game_num|
        element.each {|i| element[i].should == @check_arr[game_num][i] if i != "id"}
      end
      result.should == true
    end

    it "with other players (check order)" do
      send_request(action: "signup", params: {login: "user_c", password: "password_c"})
      send_request(action: "signin", params: {login: "user_c", password: "password_c"})
      sid_c = json_decode(response.body)['sid']
      send_request(action: "signup", params: {login: "user_1", password: "password_c"})
      send_request(action: "signin", params: {login: "user_1", password: "password_c"})
      sid_1 = json_decode(response.body)['sid']
      send_request(action: "joinGame", params: {sid: sid_c, game: game_b})
      send_request(action: "joinGame", params: {sid: sid_1, game: game_a})
      send_request(action: "getGames", params: {sid: sid_c})
      arr = json_decode(response.body)
      arr["games"][0]["players"].should == ["user_a", "user_1"]
      arr["games"][1]["players"].should == ["user_b", "user_c"]
      request_and_checking("leaveGame", {sid: sid_a})
    end

    it "with invalid sid" do
      request_and_checking("getGames", {sid: "100500"}, {result: "badSid"})
    end
  end

  describe "leave game" do
    it "with valid information" do
      request_and_checking("leaveGame", {sid: sid_b})
      send_request(action: "getGames", params: {sid: sid_a})
      arr = json_decode(response.body)
      arr["games"][1]["players"].should == ["user_c"]
    end

    it "with last player" do
      request_and_checking("leaveGame", {sid: sid_c})
      send_request(action: "getGames", params: {sid: sid_a})
      arr = json_decode(response.body)
      arr["games"].length.should == 1
    end

    it "with invalid sid(not sended)" do
      request_and_checking("leaveGame", {}, {result: "badRequest"})
    end

    it "with invalid sid" do
      request_and_checking("leaveGame", {sid: "100500"}, {result: "badSid"})
    end

    it "with notInGame" do
      request_and_checking("leaveGame", {sid: sid_b}, {result: "notInGame"})
    end
  end

  describe "join game" do
    it "with valid information" do
      request_and_checking("joinGame", {sid: sid_a, game: game_a})
    end

    it "with alreadyJoined" do
      request_and_checking("joinGame", {sid: sid_a, game: game_a}, {result: "alreadyInGame"})
    end

    it "with invalid sid" do
      request_and_checking("joinGame", {sid: "100500", game: game_a}, {result: "badSid"})
    end

    it "with invalid game id(not sended)" do
      request_and_checking("joinGame", {sid: sid_a}, {result: "badRequest"})
    end

    it "with invalid sid(not sended)" do
      request_and_checking("joinGame", {game: game_a}, {result: "badRequest"})
    end

    it "with invalid game id" do
      request_and_checking("joinGame", {sid: sid_a, game: 100500}, {result: "badGame"})
    end

    it "with full game" do
      request_and_checking("joinGame", {sid: sid_c, game: game_a})
      request_and_checking("joinGame", {sid: sid_b, game: game_a}, {result: "gameFull"})
    end
  end

  describe "get game consts" do
    it "with valid info" do
      result = {result: "ok", tickSize: Settings.tick_size, accuracy: Settings.accuracy, accel: Settings.def_game.consts.accel,
                maxVelocity: Settings.def_game.consts.maxVelocity, gravity: Settings.def_game.consts.gravity,
                friction: Settings.def_game.consts.friction}
      request_and_checking("getGameConsts", {sid: sid_a}, result)
    end

    it "with invalid sid(not sended)" do
      request_and_checking("getGameConsts", {}, {result: "badRequest"})
    end

    it "with invalid sid" do
      request_and_checking("getGameConsts", {sid: "11"}, {result: "badSid"})
    end

    it "with not in game user" do
      request_and_checking("getGameConsts", {sid: sid_b}, {result: "notInGame"})
    end

    it "with valid info (specific consts)" do
      send_request(action: "createGame", params: {sid: sid_b, name: "Tmp Game", map: map_id, maxPlayers: 3,
                                                  consts: {accel: 0.01, maxVelocity: 0.1, gravity: 0.01, friction: 0.01}})
      result = {result: "ok", tickSize: Settings.tick_size, accuracy: Settings.accuracy,
                maxVelocity: 0.1, gravity: 0.01, friction: 0.01, accel: 0.01}
      request_and_checking("getGameConsts", {sid: sid_b}, result)
      send_request(action: "leaveGame", params: {sid: sid_b})
    end
  end

  describe "send message" do
    it "with invalid sid(not sended)" do
      request_and_checking("sendMessage", {game: "", text: "message #1"}, {result: "badRequest"})
    end

    it "with invalid game(not sended)" do
      request_and_checking("sendMessage", {sid: sid_a, text: "message #1"}, {result: "badRequest"})
    end

    it "with valid information (common chat)" do
      request_and_checking("sendMessage", {sid: sid_a, game: "", text: "message #1"})
    end
    it "with valid information (game chat)" do
      request_and_checking("sendMessage", {sid: sid_a, game: game_a, text: "game_a message #1"})
    end

    it "with invalid user sid" do
      request_and_checking("sendMessage", {sid: "100500", game: "", text: "message #1"}, {result: "badSid"})
    end

    it "with invalid game id" do
      request_and_checking("sendMessage", {sid: sid_a, game: 100500, text: "message #1"}, {result: "badGame"})
    end
  end

  describe "get messages" do
    before(:all) do
      send_request(action: "sendMessage", params:{sid: sid_b, game: "", text: "message #2"})
      @check_arr = [{"login" => "user_b", "text" => "message #2"}, {"login" => "user_a", "text" => "message #1"}]
    end

    it "with invalid since(not sended)" do
      request_and_checking("getMessages", {sid: sid_b, game: ""}, {result: "badRequest"})
    end

    it "with invalid user sid(not sended)" do
      request_and_checking("getMessages", {game: "", since: 1196440219}, {result: "badRequest"})
    end

    it "with invalid game id(not sended)" do
      request_and_checking("getMessages", {sid: sid_b, since: 1196440219}, {result: "badRequest"})
    end

    it "with valid information" do
      send_request(action: "getMessages", params:{sid: sid_b, game: "", since: 1196440219})
      a_time = 1196440219
      arr = json_decode(response.body)
      result = arr["result"] == "ok"
      arr["messages"].each_with_index do |element, i|
        result &= element["login"] == @check_arr[i]["login"]
        result &= element["text"] == @check_arr[i]["text"]
        result &= a_time < element["time"].to_i
      end
      response.code.to_s.should == "200"  && result.should == true
    end

    some_message_time = 0

    it "with now 'since' parametr" do
      sleep 1
      currTime = Time.now.to_i
      sleep 1
      send_request(action: "sendMessage", params:{sid: sid_b, game: "", text: "message #3"})
      send_request(action: "getMessages", params:{sid: sid_b, game: "", since: currTime})
      arr = json_decode(response.body)
      result = arr["result"] == "ok" && arr["messages"][0]["login"] == "user_b"
      result &= arr["messages"][0]["text"] == "message #3" && arr["messages"].length == 1
      some_message_time = arr["messages"][0]['time'].to_i
      response.code.to_s.should == "200"  && result.should == true
    end

    it "with equals 'since' parametr" do
      send_request(action: "getMessages", params:{sid: sid_b, game: "", since: some_message_time})
      arr = json_decode(response.body)
      response.code.to_s.should == "200"  && arr["result"].should == "ok" && arr["messages"].length.should == 0
    end

    it "with specific game_id" do
      send_request(action: "sendMessage", params:{sid: sid_b, game: game_b, text: "game_b message #1"})
      send_request(action: "getMessages", params:{sid: sid_a, game: game_a, since: 1196440219})
      arr = json_decode(response.body)
      arr["result"].should == "ok" && arr["messages"].length.should == 1
      arr = arr['messages'][0]
      response.code.to_s.should == "200" && arr['text'].should == 'game_a message #1' && arr['login'].should == "user_a"
    end

    it "with invalid since" do
      request_and_checking("getMessages", {sid: sid_b, game: "", since: "2000-sd"}, {result: "badSince"})
    end

    it "with invalid user sid" do
      request_and_checking("getMessages", {sid: "", game: "", since: 1196440219}, {result: "badSid"})
    end

    it "with invalid game id" do
      request_and_checking("getMessages", {sid: sid_b, game: 155, since: 1196440219}, {result: "badGame"})
    end
  end

end
