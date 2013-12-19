# == Schema Information
#
# Table name: games
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Game < ActiveRecord::Base
  attr_accessible :user_id, :map_id, :name, :status, :max_players, :accel, :max_velocity, :friction, :gravity

  has_many :players
  has_many :stats
  belongs_to :map

  validates :name, presence: true, length: { minimum: 1 }, uniqueness: true
  validates :max_players, presence: true, numericality: { greater_than: 0 }

  validates_with GameMustHaveLowerMaxPlayers

  def get_stats
    stats.map do |s|
      {login: s.user.login, kills: s.kills, deaths: s.deaths}
    end
  end
end


