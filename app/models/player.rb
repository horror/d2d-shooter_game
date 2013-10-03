class Player < ActiveRecord::Base
  attr_accessible :game_id, :user_id

  #validates :user_id, :game_id, uniqueness: true
end
