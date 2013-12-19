class CreateStats < ActiveRecord::Migration
  def change
    create_table :stats, :id => false  do |t|
      t.integer :user_id
      t.integer :game_id
      t.integer :kills
      t.integer :deaths

      t.timestamps
    end
    execute "alter table stats add primary key(user_id, game_id)"
  end
end
