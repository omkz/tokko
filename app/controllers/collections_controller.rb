class CollectionsController < ApplicationController
  allow_unauthenticated_access

  def show
    @collection = Collection.find_by!(slug: params[:slug])
    @products = @collection.products.search(params[:q])

    # Sorting Logic
    case params[:sort]
    when "price_asc"
      @products = @products.joins(:product_variants)
                           .group("products.id")
                           .order("MIN(product_variants.price) ASC")
    when "price_desc"
      @products = @products.joins(:product_variants)
                           .group("products.id")
                           .order("MIN(product_variants.price) DESC")
    else
      @products = @products.order(created_at: :desc)
    end

    @pagy, @products = pagy(@products)
    
    # Load variants and image attachments/blobs without breaking the GROUP BY query
    @products = @products.preload(:product_variants, images_attachments: :blob)
    
    @collections = Collection.where(active: true)

    render "home/index"
  end
end
