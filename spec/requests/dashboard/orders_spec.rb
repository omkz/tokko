require "rails_helper"

RSpec.describe "Dashboard orders", type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    post session_path, params: { email_address: admin.email_address, password: "password123" }
  end

  it "renders item snapshots instead of current catalog text" do
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

    get dashboard_order_path(order)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Purchased Shirt", "Black / Large", "SHIRT-BLK-L")
    expect(response.body).not_to include("Renamed Shirt", "White / Small", "SHIRT-WHT-S")
  end

  describe "PATCH /dashboard/orders/:id" do
    it "allows pending orders to be cancelled" do
      order = create(:order)

      patch dashboard_order_path(order), params: { order: { status: :cancelled } }

      expect(response).to redirect_to(dashboard_order_path(order))
      expect(order.reload).to be_cancelled
    end

    it "allows paid orders to be shipped" do
      order = create(:order, :paid)

      patch dashboard_order_path(order), params: { order: { status: :shipped } }

      expect(response).to redirect_to(dashboard_order_path(order))
      expect(order.reload).to be_shipped
    end

    it "allows paid orders to be cancelled" do
      order = create(:order, :paid)

      patch dashboard_order_path(order), params: { order: { status: :cancelled } }

      expect(response).to redirect_to(dashboard_order_path(order))
      expect(order.reload).to be_cancelled
    end

    it "allows shipped orders to be completed" do
      order = create(:order, status: :shipped)

      patch dashboard_order_path(order), params: { order: { status: :completed } }

      expect(response).to redirect_to(dashboard_order_path(order))
      expect(order.reload).to be_completed
    end

    it "does not let the dashboard move a pending order to paid, shipped, or completed" do
      %w[paid shipped completed].each do |target_status|
        order = create(:order)

        patch dashboard_order_path(order), params: { order: { status: target_status } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(order.reload).to be_pending
      end
    end

    it "does not let the dashboard move a cancelled order to any other status" do
      %w[pending paid shipped completed].each do |target_status|
        order = create(:order, :cancelled)

        patch dashboard_order_path(order), params: { order: { status: target_status } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(order.reload).to be_cancelled
      end
    end
  end

  describe "available transition controls" do
    {
      pending: %w[cancelled],
      paid: %w[shipped cancelled],
      shipped: %w[completed],
      completed: [],
      cancelled: []
    }.each do |current_status, expected_targets|
      it "only shows valid transitions for a #{current_status} order" do
        order = create(:order, status: current_status)

        get dashboard_order_path(order)

        option_values = response.body.scan(/<option value="([^"]+)"/).flatten
        expect(option_values).to match_array(expected_targets)
      end
    end
  end
end
