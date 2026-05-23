class Dashboard::OrdersController < Dashboard::BaseController
  before_action :set_order, only: %i[show update]

  def index
    @pagy, @orders = pagy(Order.order(created_at: :desc))
  end

  def show
    @order_items = @order.order_items.includes(product_variant: :product)
  end

  def update
    previous_status = @order.status

    if @order.update(order_params)
      if @order.cancelled? && previous_status != "cancelled"
        @order.order_items.each do |item|
          InventoryMovement.create!(
            product_variant: item.product_variant,
            quantity: item.quantity,
            reason: :return,
            order_item: item,
            user: Current.user,
            note: "Order ##{@order.id} cancelled"
          )
        end
      end
      redirect_to dashboard_order_path(@order), notice: "Order status updated"
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  def order_params
    params.require(:order).permit(:status)
  end
end
