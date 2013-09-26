require 'spec_helper'
require 'date'

describe "Application page" do

  describe "sign up" do
    it "with valid information" do
      send_request(action: "signup", params:{login:"masha", password:"lololol", password_confirmation:"lololol"})
      response.code.should == "200"  && response.body.should == enc(result: "ok")
    end

    it "with invalid information(userExists)" do
      send_request(action: "signup", params:{login:"masha", password:"lololol", password_confirmation:"lololol"})
      response.code.should == "200"  && response.body.should == enc(result: "userExists")
    end

    it "with invalid information(too short login)" do
      send_request(action: "signup", params:{login:"vas", password:"lololol", password_confirmation:"lololol"})
      response.code.should == "200"  && response.body.should == enc(result: "badLogin")
    end

    it "with invalid information(blank login)" do
      send_request(action: "signup", params:{login:"", password:"lololol", password_confirmation:"lololol"})
      response.code.should == "200"  && response.body.should == enc(result: "badLogin")
    end

    it "with invalid information(too long login)" do
      send_request(action: "signup", params:{login: "a" * 41, password:"lololol", password_confirmation:"lololol"})
      response.code.should == "200"  && response.body.should == enc(result: "badLogin")
    end

    it "with invalid information(invalid characters in login)" do
      send_request(action: "signup", params:{login: '$%#@@$%%^', password:"lololol", password_confirmation:"lololol"})
      response.code.should == "200"  && response.body.should == enc(result: "badLogin")
    end

    it "with invalid information(too short password)" do
      send_request(action: "signup", params:{login: "vasssya", password:"lol", password_confirmation:"lol"})
      response.code.should == "200"  && response.body.should == enc(result: "badPassword")
    end

    it "with invalid information(blank password)" do
      send_request(action: "signup", params:{login: "vasssya", password:"", password_confirmation:""})
      response.code.should == "200"  && response.body.should == enc(result: "badPassword")
    end

    it "with invalid information(no confirmed password)" do
      send_request(action: "signup", params:{login: "vasssya", password:"asdsadasddsa", password_confirmation:"asxvczdds"})
      response.code.should == "200"  && response.body.should == enc(result: "badPasswordConfirmation")
    end

  end

  describe "sign in" do
    it "with valid information" do
      send_request(action: "signin", params:{login: "masha", password: "lololol"})
      response.code.should == "200" && ActiveSupport::JSON.decode(response.body)["result"].should == "ok"
    end

    it "with invalid information(incorrect login)" do
      send_request(action: "signin", params:{login: "error_login", password: "lololol"})
      response.code.should == "200" && response.body.should == enc(result: "incorrect")
    end

    it "with invalid information(incorrect password)" do
      send_request(action: "signin", params:{login: "masha", password: "error_pass"})
      response.code.should == "200" && response.body.should == enc(result: "incorrect")
    end

  end

  describe "sign out" do
    before do
      send_request(action: "signin", params:{login: "masha", password: "lololol"})
      @sid = ActiveSupport::JSON.decode(response.body)["sid"]
    end

    it "with invalid information(badSid)" do
      send_request(action: "signout", params:{sid: 100500})
      response.code.should == "200"  && response.body.should == enc(result: "badSid")
    end

    it "with valid information" do
      send_request(action: "signout", params:{sid: @sid})
      response.code.should == "200"  && response.body.should == enc(result: "ok")
    end

    it "double singout" do
      send_request(action: "signout", params:{sid: @sid})
      send_request(action: "signout", params:{sid: @sid})
      response.code.should == "200"  && response.body.should == enc(result: "badSid")
    end

  end

  describe "send message" do
    before(:all) do
      send_request(action: "signin", params:{login: "masha", password: "lololol"})
      @sid = ActiveSupport::JSON.decode(response.body)["sid"]
    end

    it "with valid information" do
      send_request(action: "sendMessage", params:{sid: @sid, game: "", text: "message #1"})
      response.code.should == "200"  && response.body.should == enc(result: "ok")
    end

    it "with invalid user sid" do
      send_request(action: "sendMessage", params:{sid: "100500", game: "", text: "message #1"})
      response.code.should == "200"  && response.body.should == enc(result: "badSid")
    end

    it "with invalid game id" do
      send_request(action: "sendMessage", params:{sid: @sid, game: 100500, text: "message #1"})
      response.code.should == "200"  && response.body.should == enc(result: "badGame")
    end

  end

  describe "get messages" do
    before(:all) do
      send_request(action: "signin", params:{login: "masha", password: "lololol"})
      @sid_user = ActiveSupport::JSON.decode(response.body)["sid"]
      send_request(action: "signup", params:{login:"author", password:"lololol", password_confirmation:"lololol"})
      send_request(action: "signin", params:{login: "author", password: "lololol"})
      @sid_author = ActiveSupport::JSON.decode(response.body)["sid"]
      send_request(action: "sendMessage", params:{sid: @sid_author, game: "", text: "message #2"})
      @check_arr = [{"login" => "author", "text" => "message #2"}, {"login" => "masha", "text" => "message #1"}]
    end

    it "with valid information" do
      send_request(action: "getMessages", params:{sid: @sid_author, game: "", since: "2000-09-19 09:49:51"})
      a_time = DateTime.parse("2000-09-19 09:49:51")
      arr = ActiveSupport::JSON.decode(response.body)
      result = arr['result'] == "ok" && arr['login'] == "author"
      for i in 0..arr['messages'].length - 1
        result &= arr['messages'][i]['login'] == @check_arr[i]['login']
        result &= arr['messages'][i]['text'] == @check_arr[i]['text']
        result &= a_time < DateTime.parse(arr['messages'][i]['time'])
      end
      response.code.should == "200"  && result.should == true
    end

    it "with now 'since' parametr" do
      send_request(action: "sendMessage", params:{sid: @sid_author, game: "", text: "message #3"})
      send_request(action: "getMessages", params:{sid: @sid_author, game: "", since: Time.now.utc.to_s(:db)})
      arr = ActiveSupport::JSON.decode(response.body)
      result = arr['result'] == "ok" && arr['login'] == "author" && arr['messages'][0]['login'] == "author"
      result &= arr['messages'][0]['text'] == "message #3"
      response.code.should == "200"  && result.should == true
    end

    it "with invalid user sid" do
      send_request(action: "getMessages", params:{sid: "100500", game: "", since: "2000-09-19 09:49:51"})
      response.code.should == "200"  && response.body.should == enc(result: "badSid")
    end

    it "with invalid game id" do
      send_request(action: "getMessages", params:{sid: @sid_author, game: 100500, since: "2000-09-19 09:49:51"})
      response.code.should == "200"  && response.body.should == enc(result: "badGame")
    end

  end
end