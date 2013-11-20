class AddConstFieldsToGames < ActiveRecord::Migration
  def change
    add_column :games, :accel, :float
    add_column :games, :max_velocity, :float
    add_column :games, :friction, :float
    add_column :games, :gravity, :float
  end
end
