require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "returns 200" do
      get root_path
      expect(response).to have_http_status(:ok)
    end

    it "shows active collections" do
      collection = create(:collection, name: "Summer Sale", active: true)
      get root_path
      expect(response.body).to include("Summer Sale")
    end

    it "does not show inactive collections" do
      create(:collection, name: "Hidden Drop", active: false)
      get root_path
      expect(response.body).not_to include("Hidden Drop")
    end

    it "shows active products without exposing draft or archived products from the same collection" do
      collection = create(:collection, name: "Featured Collection", active: true)
      active_product = create(:product, name: "Published Homepage Product", status: :active)
      draft_product = create(:product, name: "Draft Homepage Product", status: :draft)
      archived_product = create(:product, name: "Archived Homepage Product", status: :archived)

      [ active_product, draft_product, archived_product ].each do |product|
        CollectionMembership.create!(collection: collection, product: product)
      end

      get root_path

      expect(response.body).to include("Published Homepage Product")
      expect(response.body).not_to include("Draft Homepage Product")
      expect(response.body).not_to include("Archived Homepage Product")
    end

    it "does not render products from a collection containing only unpublished products" do
      collection = create(:collection, name: "Unpublished Products Collection", active: true)
      draft_product = create(:product, name: "Unpublished Draft Product", status: :draft)
      archived_product = create(:product, name: "Unpublished Archived Product", status: :archived)

      [ draft_product, archived_product ].each do |product|
        CollectionMembership.create!(collection: collection, product: product)
      end

      get root_path

      expect(response.body).not_to include("Unpublished Draft Product")
      expect(response.body).not_to include("Unpublished Archived Product")
    end
  end
end
