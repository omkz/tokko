require "rails_helper"

RSpec.describe "Coupons", type: :request do
  let(:variant) { create(:product_variant, price: 50_000, stock: 10) }

  before do
    post add_to_cart_path, params: { variant_id: variant.id, quantity: 1 }
  end

  describe "POST /coupons/validate" do
    it "returns discount details for an available coupon" do
      coupon = create(:coupon, code: "SAVE10", value: 10)

      post validate_coupon_path, params: { code: coupon.code }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "valid" => true,
        "code" => "SAVE10",
        "discount_amount" => "5000.0",
        "total" => "45000.0"
      )
    end

    it "rejects a coupon whose usage slots are reserved" do
      coupon = create(:coupon, usage_limit: 1)
      create(:order, coupon: coupon, status: :pending)

      post validate_coupon_path, params: { code: coupon.code }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("valid" => false)
    end
  end
end
