class CreateChats < ActiveRecord::Migration[6.1]
  def change
    create_table :chats do |t|
      t.integer :sent_id
      t.integer :get_id
      t.integer :chat_id
      t.string :sent_name
      t.string :text
      t.timestamps null: false
    end 
  end
end
