module CartHelper
  def cart_count
    current_cart&.item_count || 0
  end

  def cart_total_price
    current_cart&.total_price || 0
  end
end
