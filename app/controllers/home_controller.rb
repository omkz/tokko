class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
    @collections = Collection.where(active: true)
                             .includes(products: [:product_variants, { images_attachments: :blob }])
  end

  def search
    @products = Product.search(params[:q]).order(created_at: :desc)
    @pagy, @products = pagy(@products)
    @products = @products.preload(:product_variants, images_attachments: :blob)
  end
end
