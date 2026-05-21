class CreateFilterOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :filter_options do |t|
      t.references :filter_group, null: false, foreign_key: true
      t.string :value
      t.string :slug
      t.integer :position

      t.timestamps
    end
  end
end
