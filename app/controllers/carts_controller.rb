class CartsController < ApplicationController
  allow_unauthenticated_access

  def show
    cart = current_cart
    if cart
      @cart_items = cart.cart_items.includes(product_variant: :product)
      @total_price = cart.total_price
    else
      @cart_items = []
      @total_price = 0
    end
  end

  def add
    variant = ProductVariant.find(params[:variant_id])
    quantity = [ params[:quantity].to_i, 1 ].max
    cart = find_or_create_cart
    item = cart.cart_items.find_or_initialize_by(product_variant: variant)
    new_quantity = item.new_record? ? quantity : item.quantity + quantity

    if new_quantity > variant.stock
      message = variant.stock == 0 ? "#{variant.product.name} is out of stock." : "Only #{variant.stock} left in stock."
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "layouts/flash", locals: { alert: message }) }
        format.html { redirect_to request.referer || root_path, alert: message }
      end
      return
    end

    item.quantity = new_quantity
    item.save!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to cart_path, notice: "Added to cart" }
    end
  end

  def update
    quantity = params[:quantity].to_i
    cart = current_cart
    return redirect_to cart_path unless cart

    item = cart.cart_items.find_by(product_variant_id: params[:variant_id].to_i)
    if item
      quantity <= 0 ? item.destroy : item.update!(quantity: quantity)
    end

    redirect_to cart_path
  end

  def destroy
    current_cart&.cart_items&.destroy_all
    redirect_to cart_path, notice: "Cart cleared"
  end
end
