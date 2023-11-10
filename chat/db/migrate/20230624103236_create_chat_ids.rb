class CreateChatIds < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_ids do |t|
      t.integer :user_id
      t.integer :user_id2
      t.timestamps null: false
    end 
  end
end
