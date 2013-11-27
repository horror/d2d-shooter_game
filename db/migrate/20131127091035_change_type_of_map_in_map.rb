class ChangeTypeOfMapInMap < ActiveRecord::Migration
  def change
    change_table :maps do |t|
      t.change :map, :text
    end
  end
end
