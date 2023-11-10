class CreateQueues < ActiveRecord::Migration[6.1]
  def change
    create_table :queues do |t|
      t.integer :user_id
      t.timestamps null: false
    end 
  end
end
