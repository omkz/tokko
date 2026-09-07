require "rails_helper"

RSpec.describe "Dashboard product variants", type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    post session_path, params: { email_address: admin.email_address, password: "password123" }
  end

  describe "PATCH /dashboard/product_variants/:id" do
    it "ignores stock while updating permitted variant fields" do
      variant = create(:product_variant, price: 10, stock: 10)

      expect {
        patch dashboard_product_variant_path(variant), params: {
          product_variant: { stock: 50, price: 29.99 }
        }
      }.not_to change(InventoryMovement, :count)

      expect(variant.reload).to have_attributes(stock: 10, price: 29.99)
    end

    it "continues to update SKU and active state" do
      variant = create(:product_variant, sku: "ORIGINAL-SKU", active: true)

      patch dashboard_product_variant_path(variant), params: {
        product_variant: { sku: "UPDATED-SKU", active: false }
      }

      expect(variant.reload).to have_attributes(sku: "UPDATED-SKU", active: false)
    end
  end

  describe "DELETE /dashboard/product_variants/:id" do
    it "destroys an unused variant" do
      variant = create(:product_variant)

      expect {
        delete dashboard_product_variant_path(variant)
      }.to change(ProductVariant, :count).by(-1)

      expect(response).to redirect_to(edit_dashboard_product_path(variant.product))
      expect(flash[:notice]).to eq("Variant deleted")
    end

    it "archives a purchased variant and preserves its order item" do
      variant = create(:product_variant, active: true)
      order_item = create(:order_item, product_variant: variant)

      expect {
        delete dashboard_product_variant_path(variant)
      }.not_to change(ProductVariant, :count)

      expect(response).to redirect_to(edit_dashboard_product_path(variant.product))
      expect(flash[:notice]).to eq("Variant was used in an order and has been archived instead")
      expect(variant.reload).not_to be_active
      expect(order_item.reload.product_variant).to eq(variant)
    end
  end
end
