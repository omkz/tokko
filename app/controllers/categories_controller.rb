class CategoriesController < ApplicationController
  allow_unauthenticated_access

  def show
    @category = Category.find_by!(slug: params[:slug])
    
    products_query = Product.in_category(@category)
                            .search(params[:q])
                            .filter_by_facets(params[:filter])
                            .sort_by_param(params[:sort])

    @pagy, @products = pagy(products_query)
    
    # Preloads for performance
    @products = @products.preload(:product_variants, images_attachments: :blob)
  end
end
