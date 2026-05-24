require "rails_helper"

RSpec.describe "Products storefront", type: :request do
  describe "GET /products" do
    let!(:active)   { create(:product, name: "Active Shirt", status: :active) }
    let!(:draft)    { create(:product, name: "Draft Pants", status: :draft) }
    let!(:archived) { create(:product, name: "Archived Shoes", status: :archived) }

    it "returns 200" do
      get products_path
      expect(response).to have_http_status(:ok)
    end

    it "shows only active products" do
      get products_path
      expect(response.body).to include("Active Shirt")
      expect(response.body).not_to include("Draft Pants")
      expect(response.body).not_to include("Archived Shoes")
    end

    it "filters by search query" do
      get products_path, params: { q: "Shirt" }
      expect(response.body).to include("Active Shirt")
      expect(response.body).not_to include("Draft Pants")
    end

    context "when sorting by price" do
      before do
        active.product_variants.first.update!(price: 50_000)
        create(:product, name: "Expensive Jacket", status: :active).tap do |p|
          p.product_variants.first.update!(price: 200_000)
        end
      end

      it "sorts ascending" do
        get products_path, params: { sort: "price_asc" }
        expect(response.body.index("Active Shirt")).to be < response.body.index("Expensive Jacket")
      end

      it "sorts descending" do
        get products_path, params: { sort: "price_desc" }
        expect(response.body.index("Expensive Jacket")).to be < response.body.index("Active Shirt")
      end
    end
  end

  describe "GET /products/:id" do
    let!(:product) { create(:product, name: "Blue Sneakers", status: :active) }

    it "returns 200 and shows the product" do
      get product_path(product)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Blue Sneakers")
    end

    it "returns 404 for a draft product" do
      draft = create(:product, status: :draft)
      get product_path(draft)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for a non-existent product" do
      get product_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end

    it "shows related products from the same collection" do
      related = create(:product, name: "Red Sneakers", status: :active)
      collection = create(:collection)
      collection.products << [product, related]

      get product_path(product)
      expect(response.body).to include("Red Sneakers")
    end
  end
end
