class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
    if params[:collection].present?
      @collection = Collection.find_by!(slug: params[:collection])
      @pagy, @products = pagy(@collection.products.includes(:product_variants))
    else
      @pagy, @products = pagy(Product.includes(:product_variants).all)
    end
    
    @collections = Collection.where(active: true)
  end
end
