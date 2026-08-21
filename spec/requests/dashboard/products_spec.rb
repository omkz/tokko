require "rails_helper"

RSpec.describe "Dashboard products", type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    post session_path, params: { email_address: admin.email_address, password: "password123" }
  end

  describe "DELETE /dashboard/products/:id" do
    it "destroys a product without order history" do
      product = create(:product)

      expect {
        delete dashboard_product_path(id: product.id)
      }.to change(Product, :count).by(-1)

      expect(response).to redirect_to(dashboard_products_path)
      expect(flash[:notice]).to eq("Product deleted")
    end

    it "archives a product with order history and preserves historical records" do
      product = create(:product, status: :active)
      variant = product.product_variants.first
      order_item = create(:order_item, product_variant: variant)

      expect {
        delete dashboard_product_path(id: product.id)
      }.not_to change(Product, :count)

      expect(response).to redirect_to(dashboard_products_path)
      expect(flash[:notice]).to eq("Product has order history and has been archived instead")
      expect(product.reload).to be_archived
      expect(variant.reload.product).to eq(product)
      expect(order_item.reload.product_variant).to eq(variant)
    end
  end
end
