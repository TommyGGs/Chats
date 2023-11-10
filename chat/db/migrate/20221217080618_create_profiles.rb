class CreateProfiles < ActiveRecord::Migration[6.1]
  def change
    create_table :profiles do |t|
      t.references :user
      t.string :paragraph
      t.string :icon
      t.string :pronounce
      t.string :user_name
      t.timestamps null: false
    end 
  end
end
