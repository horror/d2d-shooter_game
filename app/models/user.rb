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

class User < ActiveRecord::Base
  attr_accessible :login, :password, :password_confirmation, :sid
  has_secure_password
  has_many :messages
  has_many :games
  before_save { |user| user.login = login.downcase }

  VALID_LOGIN_REGEX = /\A[\w+\-.]+\z/i
  validates :login, presence: true, length: { maximum: 40, minimum: 4 }, format: { with: VALID_LOGIN_REGEX }, uniqueness: { case_sensitive: false }
  validates :password, presence: true, length: { minimum: 4 }
  validates :password_confirmation, presence: true
end
