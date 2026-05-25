class CategoriesController < ApplicationController
  allow_unauthenticated_access

  def show
    @category = Category.friendly.find(params[:slug])

    if request.path != category_path(@category)
      return redirect_to @category, status: :moved_permanently
    end

    products_query = Product.published.in_category(@category)
                            .search(params[:q])
                            .filter_by_facets(params[:filter])
                            .sort_by_param(params[:sort])

    @pagy, @products = pagy(products_query)

    # Preloads for performance
    @products = @products.preload(:product_variants, images_attachments: :blob)
  end
end
