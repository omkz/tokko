require "rails_helper"

RSpec.describe "Dashboard products", type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    post session_path, params: { email_address: admin.email_address, password: "password123" }
  end

  describe "POST /dashboard/products" do
    it "creates an active product" do
      post dashboard_products_path, params: { product: { name: "Active Product", status: "active" } }

      product = Product.find_by!(name: "Active Product")
      expect(product).to be_active
      expect(response).to redirect_to(edit_dashboard_product_path(product))
    end

    it "creates an archived product" do
      post dashboard_products_path, params: { product: { name: "Archived Product", status: "archived" } }

      product = Product.find_by!(name: "Archived Product")
      expect(product).to be_archived
      expect(response).to redirect_to(edit_dashboard_product_path(product))
    end
  end

  describe "PATCH /dashboard/products/:id" do
    it "updates a draft product to active" do
      product = create(:product, status: :draft)

      patch dashboard_product_path(id: product.id), params: { product: { status: "active" } }

      expect(product.reload).to be_active
      expect(response).to redirect_to(dashboard_products_path)
    end

    it "updates an active product to archived" do
      product = create(:product, status: :active)

      patch dashboard_product_path(id: product.id), params: { product: { status: "archived" } }

      expect(product.reload).to be_archived
      expect(response).to redirect_to(dashboard_products_path)
    end
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
