class Dashboard::OrdersController < Dashboard::BaseController
  before_action :set_order, only: %i[show update]

  def index
    @orders = Order.order(created_at: :desc)
  end

  def show
    @order_items = @order.order_items.includes(product_variant: :product)
  end

  def update
    if @order.update(order_params)
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
