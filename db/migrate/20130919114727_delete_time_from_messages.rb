class DeleteTimeFromMessages < ActiveRecord::Migration
  def change
    remove_column :messages, :time
  end
end
