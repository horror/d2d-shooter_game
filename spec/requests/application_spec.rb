require 'spec_helper'

describe "Application page" do
  subject { page }

  describe "sign up" do
    it "with valid information" do
      send_request(action: "signup", params:{login:"vasya", password:"lololol", password_confirmation:"lololol"})
      response.code.should == "200"  && response.body.should == enc(result: "ok")
    end
  end

  describe "sand message" do
    Game.create()
    User.create(login: "lolowka", password: "lolowka", password_confirmation: "lolowka")
    it "with valid information" do
      send_request(action: "sendmessage", params:{sid: User.first.sid, game: Game.first.id, text: "lololol"})
      response.code.should == "200"  && response.body.should == enc(result: "ok")
    end
  end
end