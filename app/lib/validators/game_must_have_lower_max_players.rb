class GameMustHaveLowerMaxPlayers < ActiveModel::Validator
  def validate(record)
    if record.max_players.blank? or record.max_players > Map.find(record.map_id).max_players
      record.errors.add(:max_players, "too much count of max players")
    end
  end
end