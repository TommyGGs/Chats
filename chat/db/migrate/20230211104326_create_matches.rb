class CreateMatches < ActiveRecord::Migration[6.1]
  def change
    create_table :matches do |t|
      t.integer :user_id
      t.integer :matched_id
      t.timestamps null: false
    end 
  end
end
