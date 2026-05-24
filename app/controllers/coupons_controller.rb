class CouponsController < ApplicationController
  allow_unauthenticated_access

  def validate
    code = params[:code].to_s.upcase.strip
    coupon = Coupon.find_by(code: code)
    subtotal = current_cart&.total_price || 0

    if coupon&.valid_for_use?
      discount = coupon.discount_for(subtotal)
      render json: {
        valid: true,
        code: coupon.code,
        discount_type: coupon.discount_type,
        value: coupon.value,
        discount_amount: discount,
        total: subtotal - discount
      }
    else
      render json: { valid: false, message: coupon ? "Coupon is not valid or has expired." : "Coupon not found." }
    end
  end
end
