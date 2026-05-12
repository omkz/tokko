class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
    @products = Product.includes(:product_variants).search(params[:q])

    # Filter by Collection
    if params[:collection].present?
      @collection = Collection.find_by!(slug: params[:collection])
      @products = @collection.products.merge(@products)
    end
    
    @pagy, @products = pagy(@products.order(created_at: :desc))
    @collections = Collection.where(active: true)
  end
end
