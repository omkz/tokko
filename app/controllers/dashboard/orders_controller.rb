class Dashboard::OrdersController < Dashboard::BaseController
  before_action :set_order, only: %i[ show update ]

  # GET /dashboard/orders
  def index
    @orders = Order.includes(:order_items)
    
    # Filter by status if present
    if params[:status].present?
      @orders = @orders.where(status: params[:status])
    end

    @pagy, @orders = pagy(@orders.order(created_at: :desc))
  end

  # GET /dashboard/orders/1
  def show
    @order_items = @order.order_items.includes(product_variant: :product)
  end

  # PATCH/PUT /dashboard/orders/1
  def update
    if @order.update(order_params)
      # Define order_items again for the Turbo Stream response if needed
      @order_items = @order.order_items.includes(product_variant: :product)
      
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to dashboard_order_path(@order), notice: "Order status updated to #{@order.status.capitalize}." }
      end
    else
      redirect_to dashboard_order_path(@order), alert: "Failed to update order status."
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
