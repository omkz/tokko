class WishlistItemsController < ApplicationController
  before_action :set_item, only: :destroy

  def index
    @wishlist_items = Current.user.wishlist_items
                             .includes(product: [ :product_variants, { images_attachments: :blob } ])
                             .order(created_at: :desc)
  end

  def create
    @product = Product.find(params[:product_id])
    Current.user.wishlist_items.find_or_create_by!(product: @product)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: product_path(@product) }
    end
  end

  def destroy
    @product = @item.product
    @item.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: product_path(@product) }
    end
  end

  private

  def set_item
    @item = Current.user.wishlist_items.find(params[:id])
  end
end
