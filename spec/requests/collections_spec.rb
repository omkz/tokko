require 'rails_helper'

RSpec.describe "Collections storefront", type: :request do
  let!(:collection) { Collection.create!(name: "Winter Essentials") }
  let!(:product1) { Product.create!(name: "Warm Coat", description: "Stay warm.") }
  let!(:product2) { Product.create!(name: "Cold Gloves", description: "Keep hands cozy.") }

  before do
    # Add products to the collection
    CollectionMembership.create!(product: product1, collection: collection)
    CollectionMembership.create!(product: product2, collection: collection)

    # Update the automatically created default variants' prices for sorting tests
    product1.product_variants.first.update!(price: 150000)
    product2.product_variants.first.update!(price: 50000)
  end

  describe "GET /collections/:slug" do
    it "renders the collection page successfully" do
      get collection_path(collection)
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Winter Essentials")
      expect(response.body).to include("Warm Coat")
      expect(response.body).to include("Cold Gloves")
    end

    it "returns 404 for a non-existent collection" do
      get "/collections/non-existent-slug"
      expect(response).to have_http_status(:not_found)
    end

    it "supports sorting products by price ascending" do
      get collection_path(collection, sort: "price_asc")
      
      expect(response).to have_http_status(:ok)
      
      # Since Gloves are 50,000 and Coat is 150,000, Gloves should appear first in price_asc
      body = response.body
      coat_index = body.index("Warm Coat")
      gloves_index = body.index("Cold Gloves")
      
      expect(gloves_index).to be < coat_index
    end

    it "supports sorting products by price descending" do
      get collection_path(collection, sort: "price_desc")
      
      expect(response).to have_http_status(:ok)
      
      # Coat (150,000) should appear first in price_desc
      body = response.body
      coat_index = body.index("Warm Coat")
      gloves_index = body.index("Cold Gloves")
      
      expect(coat_index).to be < gloves_index
    end
  end
end
