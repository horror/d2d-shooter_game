class Map < ActiveRecord::Base
  attr_accessible :name, :map, :max_players

  validates :name, presence: true, uniqueness: true
end
