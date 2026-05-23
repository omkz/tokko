class MakeStockNotNullWithDefault < ActiveRecord::Migration[8.1]
  def change
    change_column_null :product_variants, :stock, false, 0
    change_column_default :product_variants, :stock, from: nil, to: 0
  end
end
