require "spec_helper"
require "date"

describe "Application page" do

  game_id = sid_b = sid_a = 0

  describe "sign up" do
    def check_it(params, result = "ok")
      request_and_checking("signup", params, {result: result})
    end

    it "with valid information" do
      check_it({login: "user_a", password: "lololol", password_confirmation: "lololol"})
    end

    it "with invalid information(userExists)" do
      check_it({login: "user_a", password: "lololol", password_confirmation: "lololol"}, "userExists")
    end

    it "with invalid information(too short login)" do
      check_it({login: "vas", password: "lololol", password_confirmation: "lololol"}, "badLogin")
    end

    it "with invalid information(blank login)" do
      check_it({login: "", password: "lololol", password_confirmation: "lololol"}, "badLogin")
    end

    it "with invalid information(too long login)" do
      check_it({login: "a" * 41, password: "lololol", password_confirmation: "lololol"}, "badLogin")
    end

    it "with invalid information(invalid characters in login)" do
      check_it({login: '$%#@@$%%^', password: "lololol", password_confirmation: "lololol"}, "badLogin")
    end

    it "with invalid information(too short password)" do
      check_it({login: "vasssya", password: "lol", password_confirmation: "lol"}, "badPassword")
    end

    it "with invalid information(blank password)" do
      check_it({login: "vasssya", password: "", password_confirmation: ""}, "badPassword")
    end

    it "with invalid information(no confirmed password)" do
      check_it({login: "vasssya", password: "asdsad", password_confirmation: "asxvc"}, "badPasswordConfirmation")
    end
  end

  describe "sign in" do
    it "with valid information" do
      send_request(action: "signin", params:{login: "user_a", password: "lololol"})
      response.code.should == "200" && json_decode(response.body)["result"].should == "ok"
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

    it "with invalid information(badSid)" do
      request_and_checking("signout", {sid: 100500}, {result: "badSid"})
    end

    it "with valid information" do
      request_and_checking("signout", {sid: sid_a})
    end

    it "double singout" do
      send_request(action: "signout", params:{sid: sid_a})
      request_and_checking("signout", {sid: sid_a}, {result: "badSid"})
    end
  end

  describe "send message" do
    before(:all) do
      send_request(action: "signin", params:{login: "user_a", password: "lololol"})
      sid_a = json_decode(response.body)["sid"]
    end

    it "with valid information" do
      request_and_checking("sendMessage", {sid: sid_a, game: "", text: "message #1"})
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
      send_request(action: "signup", params:{login: "user_b", password: "lololol", password_confirmation: "lololol"})
      send_request(action: "signin", params:{login: "user_b", password: "lololol"})
      sid_b = json_decode(response.body)["sid"]
      send_request(action: "sendMessage", params:{sid: sid_b, game: "", text: "message #2"})
      @check_arr = [{"login" => "user_b", "text" => "message #2"}, {"login" => "user_a", "text" => "message #1"}]
    end

    it "with valid information" do
      send_request(action: "getMessages", params:{sid: sid_b, game: "", since: "2000-09-19 09:49:51"})
      a_time = DateTime.parse("2000-09-19 09:49:51")
      arr = json_decode(response.body)
      result = arr["result"] == "ok" && arr["login"] == "user_b"
      arr["messages"].each_with_index do |element, i|
        result &= element["login"] == @check_arr[i]["login"]
        result &= element["text"] == @check_arr[i]["text"]
        result &= a_time < DateTime.parse(element["time"])
      end
      response.code.should == "200"  && result.should == true
    end

    it "with now 'since' parametr" do
      sleep 1
      currTime = Time.now.utc.to_s(:db)
      sleep 1
      send_request(action: "sendMessage", params:{sid: sid_b, game: "", text: "message #3"})
      send_request(action: "getMessages", params:{sid: sid_b, game: "", since: currTime})
      arr = json_decode(response.body)
      result = arr["result"] == "ok" && arr["login"] == "user_b" && arr["messages"][0]["login"] == "user_b"
      result &= arr["messages"][0]["text"] == "message #3" && arr["messages"].length == 1
      response.code.should == "200"  && result.should == true
    end

    it "with invalid since" do
      request_and_checking("getMessages", {sid: sid_b, game: "", since: "2000-sd"}, {result: "badSince"})
    end

    it "with invalid user sid" do
      request_and_checking("getMessages", {sid: "100500", game: "", since: "2000-09-19 09:49:51"}, {result: "badSid"})
    end

    it "with invalid game id" do
      request_and_checking("getMessages", {sid: sid_b, game: 155, since: "2000-09-19 09:49:51"}, {result: "badGame"})
    end
  end

  describe "create game" do
    before(:all) do
      send_request(action: "uploadMap", params: {name: "New map"})
      @map_id = json_decode(response.body)["id"]
    end

    def check_it(params, result = "ok")
      request_and_checking("createGame", params, {result: result})
    end

    it "with valid information" do
      check_it({sid: sid_a, name: "New game", map: @map_id, maxPlayers: 10})
    end

    it "with exist name" do
      check_it({sid: sid_a, name: "New game", map: @map_id, maxPlayers: 10}, "gameExists")
    end

    it "with invalid user sid" do
      check_it({sid: 100500, name: "New game1", map: @map_id, maxPlayers: 10}, "badSid")
    end

    it "with invalid map id" do
      check_it({sid: sid_a, name: "New game1", map: 100500, maxPlayers: 10}, "badMap")
    end

    it "with invalid name (blank)" do
      check_it({sid: sid_a, name: "", map: @map_id, maxPlayers: 10}, "badName")
    end

    it "with invalid maxPlayers (< 1)" do
      check_it({sid: sid_a, name: "New game1", map: @map_id, maxPlayers: 0}, "badMaxPlayers")
    end

    it "with invalid maxPlayers (blank)" do
      check_it({sid: sid_a, name: "New game1", map: @map_id, maxPlayers: ""}, "badMaxPlayers")
    end

    it "with invalid maxPlayers (is not a number)" do
      check_it({sid: sid_a, name: "New game1", map: @map_id, maxPlayers: "sda"}, "badMaxPlayers")
    end
  end

  describe "get games" do
    before(:all) do
      send_request(action: "uploadMap", params: {name: "New map 2"})
      @map_id = json_decode(response.body)["id"]
      send_request(action: "createGame", params: {sid: sid_a, name: "New game 2", map: @map_id, maxPlayers: 18})
      @check_arr = [{"name" => "New game", "map" => "New map", "maxPlayers" => 10, "status" => "running"},
                    {"name" => "New game 2", "map" => "New map 2", "maxPlayers" => 18, "status" => "running"}]
    end

    it "with valid information" do
      send_request(action: "getGames", params: {sid: sid_a})
      arr = json_decode(response.body)
      result = arr["result"] == "ok"
      game_id = arr["games"][0]["id"]
      arr["games"].each_with_index do |element, i|
        result &= element["name"] == @check_arr[i]["name"] && element["map"] == @check_arr[i]["map"]
        result &= element["maxPlayers"] == @check_arr[i]["maxPlayers"] && element["status"] == @check_arr[i]["status"]
      end
      result.should == true
    end

    it "with players" do
      @players = ["user_a", "user_b"]
      send_request(action: "joinGame", params: {sid: sid_a, game: game_id})
      send_request(action: "joinGame", params: {sid: sid_b, game: game_id})
      send_request(action: "getGames", params: {sid: sid_a})
      arr = json_decode(response.body)
      arr["games"].each do |element|
        if element["id"] == game_id 
          arr["result"].should == "ok" && element["players"].should == @players
        end
      end
    end

    it "with invalid sid" do
      request_and_checking("getGames", {sid: 100500}, {result: "badSid"})
    end
  end

  describe "join game" do
    it "with valid information" do
      request_and_checking("joinGame", {sid: sid_a, game: game_id})
    end
  end
end