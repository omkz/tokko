class ProductsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  
  def index
    products_query = Product.search(params[:q])
                            .filter_by_facets(params[:filter])
                            .sort_by_param(params[:sort])

    @pagy, @products = pagy(products_query)
    
    # Preloads for performance
    @products = @products.preload(:product_variants, images_attachments: :blob)
  end
  
  def show
    @product = Product.includes(:product_variants).find(params[:id])
    @variants = @product.product_variants.includes(:product_option_values)
    @related_products = @product.related_products(4).includes(:product_variants)
  end
end
