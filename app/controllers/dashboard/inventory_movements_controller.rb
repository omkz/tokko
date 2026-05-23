class Dashboard::InventoryMovementsController < Dashboard::BaseController
  def index
    @movements = InventoryMovement.includes(
      :user,
      :order_item,
      product_variant: :product
    )

    if params[:reason].present?
      @movements = @movements.where(reason: params[:reason])
    end

    if params[:q].present?
      @movements = @movements.joins(product_variant: :product)
                             .where("products.name ILIKE ?", "%#{params[:q]}%")
    end

    @pagy, @movements = pagy(@movements.order(created_at: :desc))
  end
end
