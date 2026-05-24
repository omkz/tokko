class Dashboard::CouponsController < Dashboard::BaseController
  before_action :set_coupon, only: [ :edit, :update, :destroy ]

  def index
    @coupons = Coupon.includes(:orders).order(created_at: :desc)
  end

  def new
    @coupon = Coupon.new
  end

  def create
    @coupon = Coupon.new(coupon_params)
    if @coupon.save
      redirect_to dashboard_coupons_path, notice: "Coupon created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @coupon.update(coupon_params)
      redirect_to dashboard_coupons_path, notice: "Coupon updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @coupon.destroy
    redirect_to dashboard_coupons_path, notice: "Coupon deleted."
  end

  private

  def set_coupon
    @coupon = Coupon.find(params[:id])
  end

  def coupon_params
    params.require(:coupon).permit(:code, :discount_type, :value, :minimum_order, :usage_limit, :expires_at, :active)
  end
end
