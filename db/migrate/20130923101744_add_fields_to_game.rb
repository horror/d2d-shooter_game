class AddFieldsToGame < ActiveRecord::Migration
  def change
    add_column :games, :user_id, :integer
    add_column :games, :map_id, :integer
    add_column :games, :max_players, :integer
    add_column :games, :name, :string
  end
end
