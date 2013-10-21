class Player < ActiveRecord::Base
  attr_accessible :game_id, :user_id

  belongs_to :game
  #validates :user_id, :game_id, uniqueness: true
end
