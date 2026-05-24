class CreateAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :first_name
      t.string :last_name
      t.string :address1
      t.string :city
      t.string :state
      t.string :zipcode
      t.string :country
      t.string :phone
      t.boolean :is_default, default: false, null: false

      t.timestamps
    end
  end
end
