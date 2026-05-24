require "rails_helper"

RSpec.describe "Checkouts", type: :request do
  let(:variant) { create(:product_variant, price: 50_000, stock: 10) }

  let(:valid_order_params) do
    {
      order: {
        customer_name: "Budi Santoso",
        customer_email: "budi@example.com",
        customer_phone: "08123456789",
        shipping_address: "Jl. Sudirman No. 1, Jakarta"
      }
    }
  end

  def setup_cart(quantity: 1)
    post add_to_cart_path, params: { variant_id: variant.id, quantity: quantity }
  end

  def fake_stripe_session(url: "https://checkout.stripe.com/pay/fake")
    double("Stripe::Checkout::Session", id: "cs_test_fake", url: url)
  end

  describe "GET /checkout/new" do
    it "redirects to root when cart is empty" do
      get new_checkout_path
      expect(response).to redirect_to(root_path)
    end

    it "renders the checkout form when cart has items" do
      setup_cart
      get new_checkout_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /checkout" do
    context "with an empty cart" do
      it "redirects to root" do
        post checkout_path, params: valid_order_params
        expect(response).to redirect_to(root_path)
      end
    end

    context "with a valid cart" do
      before do
        setup_cart(quantity: 2)
        allow(Stripe::Checkout::Session).to receive(:create).and_return(fake_stripe_session)
      end

      it "creates an order" do
        expect {
          post checkout_path, params: valid_order_params
        }.to change(Order, :count).by(1)
      end

      it "sets order status to pending" do
        post checkout_path, params: valid_order_params
        expect(Order.last.status).to eq("pending")
      end

      it "sets order total_price correctly" do
        post checkout_path, params: valid_order_params
        expect(Order.last.total_price).to eq(variant.price * 2)
      end

      it "creates order items with unit_price snapshot" do
        post checkout_path, params: valid_order_params
        order = Order.last
        expect(order.order_items.first.unit_price).to eq(variant.price)
      end

      it "creates an inventory movement for each item" do
        expect {
          post checkout_path, params: valid_order_params
        }.to change(InventoryMovement, :count).by(1)

        movement = InventoryMovement.last
        expect(movement.quantity).to eq(-2)
        expect(movement.reason).to eq("sale")
      end

      it "decrements variant stock" do
        post checkout_path, params: valid_order_params
        expect(variant.reload.stock).to eq(8)
      end

      it "clears cart items after checkout" do
        post checkout_path, params: valid_order_params
        expect(Cart.find_by(user: nil)&.cart_items).to be_blank
      end

      it "redirects to Stripe checkout URL" do
        post checkout_path, params: valid_order_params
        expect(response).to redirect_to("https://checkout.stripe.com/pay/fake")
      end
    end

    context "with multiple variants in cart" do
      let(:variant2) { create(:product_variant, price: 30_000, stock: 5) }

      before do
        setup_cart(quantity: 1)
        post add_to_cart_path, params: { variant_id: variant2.id, quantity: 2 }
        allow(Stripe::Checkout::Session).to receive(:create).and_return(fake_stripe_session)
      end

      it "creates order items for all variants" do
        post checkout_path, params: valid_order_params
        expect(Order.last.order_items.count).to eq(2)
      end

      it "calculates total across all items" do
        post checkout_path, params: valid_order_params
        expected_total = variant.price * 1 + variant2.price * 2
        expect(Order.last.total_price).to eq(expected_total)
      end

      it "decrements stock for all variants" do
        post checkout_path, params: valid_order_params
        expect(variant.reload.stock).to eq(9)
        expect(variant2.reload.stock).to eq(3)
      end
    end

    context "with an out of stock variant" do
      before { setup_cart(quantity: 1) }

      it "does not create an order when stock is 0" do
        variant.update!(stock: 0)
        expect {
          post checkout_path, params: valid_order_params
        }.not_to change(Order, :count)
      end

      it "renders the checkout form with an error" do
        variant.update!(stock: 0)
        post checkout_path, params: valid_order_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with stock that runs out during checkout" do
      before do
        setup_cart(quantity: 2)
        variant.update!(stock: 1)
      end

      it "does not create an order" do
        expect {
          post checkout_path, params: valid_order_params
        }.not_to change(Order, :count)
      end

      it "does not decrement stock" do
        post checkout_path, params: valid_order_params
        expect(variant.reload.stock).to eq(1)
      end

      it "renders the checkout form with an error" do
        post checkout_path, params: valid_order_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with missing required order fields" do
      before do
        setup_cart
        allow(Stripe::Checkout::Session).to receive(:create).and_return(fake_stripe_session)
      end

      it "does not create an order" do
        expect {
          post checkout_path, params: { order: { customer_name: "" } }
        }.not_to change(Order, :count)
      end
    end
  end

  describe "GET /checkout/success" do
    it "renders the success page for a valid order" do
      order = create(:order)
      get success_checkout_path(order_id: order.id)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /checkout/payment_success" do
    it "renders the payment success page when Stripe session matches an order" do
      order = create(:order, stripe_checkout_session_id: "cs_test_abc")
      stripe_session = double("Stripe::Checkout::Session", id: "cs_test_abc")
      allow(Stripe::Checkout::Session).to receive(:retrieve).with("cs_test_abc").and_return(stripe_session)

      get payment_success_checkout_path(session_id: "cs_test_abc")
      expect(response).to have_http_status(:ok)
    end
  end
end
