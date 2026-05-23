class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
    @collections = Collection.where(active: true)
                             .includes(products: [:product_variants, { images_attachments: :blob }])
  end

  def search
    @products = Product.search(params[:q])

    case params[:sort]
    when "price_asc"
      @products = @products.joins(:product_variants).group("products.id").order("MIN(product_variants.price) ASC")
    when "price_desc"
      @products = @products.joins(:product_variants).group("products.id").order("MIN(product_variants.price) DESC")
    else
      @products = @products.order(created_at: :desc)
    end

    @pagy, @products = pagy(@products)
    @products = @products.preload(:product_variants, images_attachments: :blob)
  end
end
