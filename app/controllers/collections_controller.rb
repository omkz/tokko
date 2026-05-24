class CollectionsController < ApplicationController
  allow_unauthenticated_access

  def show
    @collection = Collection.find_by!(slug: params[:slug])

    products_query = @collection.products.published
                                .search(params[:q])
                                .filter_by_facets(params[:filter])
                                .sort_by_param(params[:sort])

    @pagy, @products = pagy(products_query)

    # Load variants and image attachments/blobs without breaking the GROUP BY query
    @products = @products.preload(:product_variants, images_attachments: :blob)
  end
end
