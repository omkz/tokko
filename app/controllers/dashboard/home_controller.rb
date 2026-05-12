class Dashboard::HomeController < Dashboard::BaseController
  def index
    @total_revenue = Order.total_revenue
    @orders_count = Order.count
    @products_count = Product.count
    @recent_orders = Order.order(created_at: :desc).limit(5)
    
    @sales_data = (6.days.ago.to_date..Date.today).map do |date|
      {
        date: date.strftime("%b %d"),
        revenue: Order.revenue_on(date)
      }
    end
  end
end
