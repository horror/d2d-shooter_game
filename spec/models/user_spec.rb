# == Schema Information
#
# Table name: users
#
#  id              :integer          not null, primary key
#  login           :string(255)
#  password_digest :string(255)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  sid             :string(255)
#

# == Schema Information
#
# Table name: users
#
#  id              :integer          not null, primary key
#  login           :string(255)
#  password_digest :string(255)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
require 'spec_helper'

describe User do

  before(:all) do
    @user = User.create(login: "ExampleUser",
                     password: "Example password", password_confirmation: "Example password")
  end

  subject { @user }

  it { should respond_to(:login) }
  it { should respond_to(:password_digest) }
  it { should respond_to(:password) }
  it { should respond_to(:password_confirmation) }
  it { should respond_to(:sid) }
  it { should respond_to(:authenticate) }

  it { should be_valid }

  describe "when name is not present" do
    before { @user.login = " " }
    it { should_not be_valid }
  end

  describe "when login is too long" do
    before { @user.login = "a" * 41 }
    it { should_not be_valid }
  end

  describe "when login is too short" do
    before { @user.password = "a" * 3 }
    it { should_not be_valid }
  end

  describe "when login is already taken" do
    before do
      user_with_same_login = @user.dup
      user_with_same_login.login = @user.login.upcase
      user_with_same_login.save
    end

    it { should_not be_valid }
  end

  describe "when password is not present" do
    before { @user.password = @user.password_confirmation = " " }
    it { should_not be_valid }
  end

  describe "when password doesn't match confirmation" do
    before { @user.password_confirmation = "mismatch" }
    it { should_not be_valid }
  end

  describe "when password confirmation is nil" do
    before { @user.password_confirmation = nil }
    it { should_not be_valid }
  end

  describe "with a password that's too short" do
    before { @user.password = @user.password_confirmation = "a" * 3 }
    it { should be_invalid }
  end

  describe "return value of authenticate method" do

    describe "with valid password" do
      it { should == @user.authenticate(@user.password) }
    end

    describe "with invalid password" do
      let(:user_for_invalid_password) { @user.authenticate("invalid") }

      it { should_not == user_for_invalid_password }
      specify { user_for_invalid_password.should be_false }
    end
  end

end
