class AddSnapshotsToOrderItems < ActiveRecord::Migration[8.1]
  def up
    add_column :order_items, :product_name, :string
    add_column :order_items, :variant_options, :string
    add_column :order_items, :variant_sku, :string

    execute <<~SQL
      UPDATE order_items
      SET product_name = COALESCE(NULLIF(BTRIM(products.name), ''), 'Unknown Product'),
          variant_options = COALESCE(
            NULLIF(BTRIM(snapshot_options.option_text), ''),
            NULLIF(BTRIM(product_variants.title), ''),
            'Default Title'
          ),
          variant_sku = COALESCE(NULLIF(BTRIM(product_variants.sku), ''), 'Unknown SKU')
      FROM product_variants
      INNER JOIN products ON products.id = product_variants.product_id
      LEFT JOIN (
        SELECT variant_option_values.product_variant_id,
               STRING_AGG(
                 product_option_values.value,
                 ' / ' ORDER BY product_options.position NULLS LAST,
                                product_option_values.position NULLS LAST,
                                variant_option_values.id
               ) FILTER (WHERE NULLIF(BTRIM(product_option_values.value), '') IS NOT NULL) AS option_text
        FROM variant_option_values
        INNER JOIN product_option_values
          ON product_option_values.id = variant_option_values.product_option_value_id
        INNER JOIN product_options
          ON product_options.id = product_option_values.product_option_id
        GROUP BY variant_option_values.product_variant_id
      ) snapshot_options ON snapshot_options.product_variant_id = product_variants.id
      WHERE order_items.product_variant_id = product_variants.id
    SQL

    change_column_null :order_items, :product_name, false
    change_column_null :order_items, :variant_options, false
    change_column_null :order_items, :variant_sku, false
  end

  def down
    remove_columns :order_items, :product_name, :variant_options, :variant_sku
  end
end
