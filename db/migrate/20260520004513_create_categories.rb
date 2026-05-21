class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name
      t.string :slug
      t.text :description
      t.bigint :parent_id
      t.integer :position

      t.timestamps
    end
    add_index :categories, :slug, unique: true
    add_index :categories, :parent_id
  end
end
