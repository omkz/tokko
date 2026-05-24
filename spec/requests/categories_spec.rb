require "rails_helper"

RSpec.describe "Categories storefront", type: :request do
  let!(:category) { create(:category, name: "Footwear") }
  let!(:product)  { create(:product, name: "Running Shoes", status: :active, category: category) }

  describe "GET /categories/:slug" do
    it "returns 200 and shows category products" do
      get category_path(category)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Running Shoes")
    end

    it "returns 404 for a non-existent category" do
      get "/categories/non-existent-slug"
      expect(response).to have_http_status(:not_found)
    end

    it "excludes draft products" do
      create(:product, name: "Draft Boot", status: :draft, category: category)
      get category_path(category)
      expect(response.body).not_to include("Draft Boot")
    end

    it "includes products from child categories" do
      child = create(:category, name: "Sandals", parent: category)
      create(:product, name: "Flip Flops", status: :active, category: child)

      get category_path(category)
      expect(response.body).to include("Flip Flops")
    end

    it "filters by search query" do
      create(:product, name: "Leather Boots", status: :active, category: category)
      get category_path(category, q: "Running")
      expect(response.body).to include("Running Shoes")
      expect(response.body).not_to include("Leather Boots")
    end
  end
end
