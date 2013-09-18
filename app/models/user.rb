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

class User < ActiveRecord::Base
  attr_accessible :login, :password, :password_confirmation
  has_secure_password

  before_save { |user| user.login = login.downcase }

  VALID_LOGIN_REGEX = /\A[\w+\-.]+\z/i
  validates :login, presence: true, length: { maximum: 50, minimum: 4 }, format: { with: VALID_LOGIN_REGEX }, uniqueness: { case_sensitive: false }
  validates :password, presence: true, length: { minimum: 6 }
  validates :password_confirmation, presence: true
end
