class CreateFilterGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :filter_groups do |t|
      t.string :name
      t.string :slug
      t.integer :position

      t.timestamps
    end
    add_index :filter_groups, :slug, unique: true
  end
end
