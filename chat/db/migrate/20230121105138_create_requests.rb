class CreateRequests < ActiveRecord::Migration[6.1]
  def change
    create_table :requests do |t|
      t.integer :get_id
      t.integer :sent_id
    end 
  end
end