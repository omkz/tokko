class ProductsController < ApplicationController
  allow_unauthenticated_access only: :show
  
  def show
    @product = Product.includes(:product_variants).find(params[:id])
    @variants = @product.product_variants.includes(:product_option_values)
    @related_products = @product.related_products(4).includes(:product_variants)
  end
end
