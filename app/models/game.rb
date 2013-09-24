# == Schema Information
#
# Table name: games
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Game < ActiveRecord::Base
  attr_accessible :user_id, :map_id, :name, :max_players

  has_many :players
end
