class ProductsController < ApplicationController
  allow_unauthenticated_access only: %i[index show]
  
  def index
    products_query = Product.published
                            .search(params[:q])
                            .filter_by_facets(params[:filter])
                            .sort_by_param(params[:sort])

    @pagy, @products = pagy(products_query)
    
    # Preloads for performance
    @products = @products.preload(:product_variants, images_attachments: :blob)
  end
  
  def show
    @product = Product.published.includes(
      product_variants: { product_option_values: :product_option },
      images_attachments: :blob
    ).find(params[:id])
    @variants = @product.product_variants
    @related_products = @product.related_products(4).includes(:product_variants, images_attachments: :blob)
  end
end
