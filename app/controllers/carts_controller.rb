class CartsController < ApplicationController
  allow_unauthenticated_access
  before_action :initialize_cart

  def show
    @cart_items = []
    @total_price = 0
    
    session[:cart].each do |variant_id, quantity|
      variant = ProductVariant.includes(:product).find_by(id: variant_id)
      if variant
        item_total = variant.price.to_i * quantity.to_i
        @cart_items << { variant: variant, quantity: quantity, total: item_total }
        @total_price += item_total
      end
    end
  end

  def add
    variant_id = params[:variant_id].to_s
    quantity = params[:quantity].to_i > 0 ? params[:quantity].to_i : 1
    
    session[:cart][variant_id] ||= 0
    session[:cart][variant_id] += quantity
    
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to cart_path, notice: "Added to cart" }
    end
  end

  def update
    variant_id = params[:variant_id].to_s
    quantity = params[:quantity].to_i
    
    if quantity <= 0
      session[:cart].delete(variant_id)
    else
      session[:cart][variant_id] = quantity
    end
    
    redirect_to cart_path
  end

  def destroy
    session[:cart] = {}
    redirect_to cart_path, notice: "Cart cleared"
  end

  private

  def initialize_cart
    session[:cart] ||= {}
  end
end
