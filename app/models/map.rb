class Map < ActiveRecord::Base
  attr_accessible :name, :map, :map_playes

  validates :name, presence: true, uniqueness: true
end
