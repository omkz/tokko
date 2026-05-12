module CartHelper
  def cart_count
    return 0 unless session[:cart]
    session[:cart].values.sum
  end

  def cart_total_price
    return 0 unless session[:cart]
    
    session[:cart].sum do |variant_id, quantity|
      variant = ProductVariant.find_by(id: variant_id)
      variant ? (variant.price.to_i * quantity.to_i) : 0
    end
  end
end
