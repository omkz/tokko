class AddStockNonNegativeConstraint < ActiveRecord::Migration[8.1]
  def up
    add_check_constraint :product_variants, "stock >= 0", name: "stock_non_negative"
  end

  def down
    remove_check_constraint :product_variants, name: "stock_non_negative"
  end
end
