class ChangeQueue < ActiveRecord::Migration[6.1]
  def change
    rename_table :queues, :waitings
  end
end
