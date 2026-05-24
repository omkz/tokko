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
  end
end
