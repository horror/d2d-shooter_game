class AddFieldsForMaps < ActiveRecord::Migration
  def change
    add_column :maps, :map, :string
    add_column :maps, :max_players, :integer
  end
end
