class CreateCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :collections do |t|
      t.string :name
      t.string :slug
      t.text :description
      t.boolean :active

      t.timestamps
    end
    add_index :collections, :slug, unique: true
  end
end
