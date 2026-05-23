class Dashboard::HomeController < Dashboard::BaseController
  def index
    @total_revenue = Order.total_revenue
    @orders_count = Order.count
    @products_count = Product.count
    @low_stock_count = ProductVariant.where("stock > 0 AND stock <= 5").count

    @recent_orders = Order.order(created_at: :desc).limit(5)

    @top_products = Product.best_sellers

    @sales_data = (6.days.ago.to_date..Date.today).map do |date|
      { date: date.strftime("%b %d"), revenue: Order.revenue_on(date) }
    end
  end
end
