require "rails_helper"

RSpec.describe "Carts", type: :request do
  let(:variant) { create(:product_variant, price: 50_000, stock: 10) }

  def guest_cart
    Cart.find_by(user: nil)
  end

  describe "GET /cart" do
    it "renders successfully with an empty cart" do
      get cart_path
      expect(response).to have_http_status(:ok)
    end

    it "shows items in the cart" do
      post add_to_cart_path, params: { variant_id: variant.id, quantity: 1 }

      get cart_path
      expect(response.body).to include(variant.product.name)
    end
  end

  describe "POST /cart/add" do
    it "creates a guest cart on first add" do
      expect {
        post add_to_cart_path, params: { variant_id: variant.id, quantity: 1 }
      }.to change(Cart, :count).by(1)
    end

    it "adds the item with the correct quantity" do
      post add_to_cart_path, params: { variant_id: variant.id, quantity: 2 }
      expect(guest_cart.cart_items.first.quantity).to eq(2)
    end

    it "increments quantity when the same variant is added again" do
      post add_to_cart_path, params: { variant_id: variant.id, quantity: 1 }
      post add_to_cart_path, params: { variant_id: variant.id, quantity: 3 }
      expect(guest_cart.item_count).to eq(4)
    end

    it "does not create a new cart on subsequent adds" do
      post add_to_cart_path, params: { variant_id: variant.id, quantity: 1 }
      expect {
        post add_to_cart_path, params: { variant_id: variant.id, quantity: 1 }
      }.not_to change(Cart, :count)
    end

    it "rejects quantity exceeding stock" do
      post add_to_cart_path, params: { variant_id: variant.id, quantity: 99 }
      expect(guest_cart&.cart_items).to be_blank
    end

    context "when variant is out of stock" do
      let(:variant) { create(:product_variant, stock: 0) }

      it "rejects the add and shows an error" do
        post add_to_cart_path, params: { variant_id: variant.id, quantity: 1 }
        expect(guest_cart&.cart_items).to be_blank
      end
    end
  end

  describe "PATCH /cart" do
    before { post add_to_cart_path, params: { variant_id: variant.id, quantity: 2 } }

    it "updates the item quantity" do
      patch cart_path, params: { variant_id: variant.id, quantity: 5 }
      expect(guest_cart.cart_items.first.reload.quantity).to eq(5)
    end

    it "removes the item when quantity is 0" do
      patch cart_path, params: { variant_id: variant.id, quantity: 0 }
      expect(guest_cart.cart_items.reload).to be_empty
    end

    it "removes the item when quantity is negative" do
      patch cart_path, params: { variant_id: variant.id, quantity: -1 }
      expect(guest_cart.cart_items.reload).to be_empty
    end
  end

  describe "DELETE /cart" do
    before { post add_to_cart_path, params: { variant_id: variant.id, quantity: 1 } }

    it "clears all cart items" do
      delete cart_path
      expect(guest_cart.cart_items.reload).to be_empty
    end

    it "keeps the cart record itself" do
      cart_id = guest_cart.id
      delete cart_path
      expect(Cart.exists?(cart_id)).to be true
    end
  end
end
