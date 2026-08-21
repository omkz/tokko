class Dashboard::OrdersController < Dashboard::BaseController
  before_action :set_order, only: %i[show update]

  def index
    @pagy, @orders = pagy(Order.order(created_at: :desc))
  end

  def show
    @order_items = @order.order_items.includes(product_variant: :product)
  end

  def update
    if transition_order
      redirect_to dashboard_order_path(@order), notice: "Order status updated"
    else
      @order_items = @order.order_items.includes(product_variant: :product)
      flash.now[:alert] = @order.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  private

  def transition_order
    case order_params[:status]
    when "shipped" then @order.ship!
    when "completed" then @order.complete!
    else
      @order.errors.add(:status, "is not available from the dashboard")
      false
    end
  end

  def set_order
    @order = Order.find(params[:id])
  end

  def order_params
    params.require(:order).permit(:status)
  end
end
