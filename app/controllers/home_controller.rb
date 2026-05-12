class HomeController < ApplicationController
  allow_unauthenticated_access
  def index
    @products = Product.includes(:product_variants).where(status: "active")
  end
end
