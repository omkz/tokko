class CreateProductFilterOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :product_filter_options do |t|
      t.references :product, null: false, foreign_key: true
      t.references :filter_option, null: false, foreign_key: true

      t.timestamps
    end
  end
end
