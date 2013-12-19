class Stat < ActiveRecord::Base
  require "composite_primary_keys"
  attr_accessible :deaths, :game_id, :kills, :user_id
  self.primary_keys = :user_id, :game_id
end
