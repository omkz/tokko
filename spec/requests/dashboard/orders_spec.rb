require "rails_helper"

RSpec.describe "Dashboard orders", type: :request do
  it "renders item snapshots instead of current catalog text" do
    admin = create(:user, :admin)
    variant = create(:product_variant)
    order = create(:order)
    create(
      :order_item,
      order: order,
      product_variant: variant,
      product_name: "Purchased Shirt",
      variant_options: "Black / Large",
      variant_sku: "SHIRT-BLK-L"
    )
    variant.product.update!(name: "Renamed Shirt")
    variant.update!(title: "White / Small", sku: "SHIRT-WHT-S")
    post session_path, params: { email_address: admin.email_address, password: "password123" }

    get dashboard_order_path(order)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Purchased Shirt", "Black / Large", "SHIRT-BLK-L")
    expect(response.body).not_to include("Renamed Shirt", "White / Small", "SHIRT-WHT-S")
  end
end
