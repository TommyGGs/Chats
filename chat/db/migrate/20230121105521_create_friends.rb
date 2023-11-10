class CreateFriends < ActiveRecord::Migration[6.1]
  def change
     create_table :friends do |t|
      t.integer :get_friend_id
      t.integer :sent_friend_id
    end 
  end
end
