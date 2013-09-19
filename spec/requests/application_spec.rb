require 'spec_helper'

describe "Application page" do
  subject { page }

  describe "sign up" do
    it "with valid information" do
      xhr :post, "/", enc(action: "signup", params:{login:"vasya", password:"lololol", password_confirmation:"lololol"}), "CONTENT_TYPE" => 'application/json; charset=utf-8', "DATA_TYPE" => 'json'
      response.code.should == "200"  && response.body.should == enc(result: "ok")
    end
  end
end