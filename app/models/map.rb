class Map < ActiveRecord::Base
  attr_accessible :name, :map, :max_players

  validates_each :map do |record, attr, value|
    map_data = ActiveSupport::JSON.decode(value)
    is_valid = map_data.is_a?(Array)
    if is_valid
      line_size = map_data[0].length
      map_data.each do |line|
        if line.length != line_size or (line =~ /^[\w\d#\$\.]+$/) == nil
          is_valid = false
          break
        end
      end
    end
    record.errors.add(attr, 'must be in game map format') unless is_valid
  end

  validates :name, presence: true, uniqueness: true
  validates :max_players, presence: true, numericality: { greater_than: 0 }
end
