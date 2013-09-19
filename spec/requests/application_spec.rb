require 'spec_helper'

describe "Application page" do
  subject { page }

  describe "sign up" do

    let(:user) { FactoryGirl.create(:user) }

    it "with valid information" do
      send_request(action: "signup", params:{login:"vasya", password:"lololol", password_confirmation:"lololol"})
      response.code.should == "200"  && response.body.should == enc(result: "ok")
    end

    it "with invalid information(userExists)" do
      send_request(action: "signup", params:{login:user.login, password:"lololol", password_confirmation:"lololol"})
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

  describe "send message" do
    Game.create()
    User.create(login: "lolowka", password: "lolowka", password_confirmation: "lolowka")
    it "with valid information" do
      send_request(action: "sendmessage", params:{sid: User.first.sid, game: Game.first.id, text: "lololol"})
      response.code.should == "200"  && response.body.should == enc(result: "ok")
    end
  end
end