class CreateVariantOptionValues < ActiveRecord::Migration[8.1]
  def change
    create_table :variant_option_values do |t|
      t.references :product_variant, null: false, foreign_key: true
      t.references :product_option_value, null: false, foreign_key: true

      t.timestamps
    end
  end
end
