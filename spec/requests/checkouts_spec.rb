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

  it "configures Stripe network retries" do
    expect(Stripe.max_network_retries).to eq(2)
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

      it "creates an inventory reservation for each item" do
        expect {
          post checkout_path, params: valid_order_params
        }.to change(InventoryMovement, :count).by(1)

        movement = InventoryMovement.last
        expect(movement.quantity).to eq(-2)
        expect(movement.reason).to eq("reservation")
      end

      it "decrements variant stock" do
        post checkout_path, params: valid_order_params
        expect(variant.reload.stock).to eq(8)
      end

      it "does not clear cart items until payment is confirmed" do
        post checkout_path, params: valid_order_params
        expect(Cart.find_by(user: nil)&.cart_items).not_to be_blank
      end

      it "redirects to Stripe checkout URL" do
        post checkout_path, params: valid_order_params
        expect(response).to redirect_to("https://checkout.stripe.com/pay/fake")
      end

      it "stores the Stripe session ID while keeping the reservation pending" do
        post checkout_path, params: valid_order_params

        order = Order.last
        expect(order).to be_pending
        expect(order.stripe_checkout_session_id).to eq("cs_test_fake")
        expect(order.inventory_movements.sole).to be_reservation
        expect(variant.reload.stock).to eq(8)
      end

      it "creates the Stripe session with reconciliation fields and an idempotency key" do
        allow(Stripe::Checkout::Session).to receive(:create) do |session_params, request_options|
          order = Order.last
          expect(session_params).to include(
            client_reference_id: order.id.to_s,
            metadata: { order_id: order.id }
          )
          expect(session_params[:expires_at]).to be_within(5).of(30.minutes.from_now.to_i)
          expect(request_options).to eq(idempotency_key: "checkout-session-order-#{order.id}")
          fake_stripe_session
        end

        post checkout_path, params: valid_order_params

        expect(response).to redirect_to("https://checkout.stripe.com/pay/fake")
      end
    end

    context "when Stripe Checkout Session creation definitively fails" do
      let(:coupon) { create(:coupon, usage_limit: 1) }

      before do
        setup_cart(quantity: 2)
        allow(Stripe::Coupon).to receive(:create).and_return(double("Stripe::Coupon", id: "coupon_test_fake"))
        allow(Stripe::Checkout::Session).to receive(:create)
          .and_raise(Stripe::InvalidRequestError.new("Invalid request", "line_items"))
      end

      it "cancels the order and releases inventory and coupon reservations" do
        params = valid_order_params.deep_merge(order: { coupon_code: coupon.code })

        post checkout_path, params: params

        order = Order.last
        expect(order).to be_cancelled
        expect(order.stripe_checkout_session_id).to be_blank
        expect(order.inventory_movements.pluck(:reason)).to contain_exactly("reservation", "release")
        expect(variant.reload.stock).to eq(10)
        expect(coupon).to be_valid_for_use
      end

      it "keeps the cart intact and shows a retryable error" do
        params = valid_order_params.deep_merge(order: { coupon_code: coupon.code })

        expect {
          post checkout_path, params: params
        }.not_to have_enqueued_mail(OrderMailer, :confirmation)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("We couldn&#39;t start the payment session. Please try again.")
        expect(Cart.find_by(user: nil).cart_items).not_to be_empty
      end

      it "does not leave a pending order without a Stripe session" do
        post checkout_path, params: valid_order_params

        expect(Order.where(status: :pending, stripe_checkout_session_id: [ nil, "" ])).to be_empty
      end
    end

    shared_examples "an indeterminate Stripe Checkout failure" do
      let(:coupon) { create(:coupon, usage_limit: 1) }

      before do
        setup_cart(quantity: 2)
        allow(Stripe::Coupon).to receive(:create).and_return(double("Stripe::Coupon", id: "coupon_test_fake"))
        allow(Stripe::Checkout::Session).to receive(:create).and_raise(stripe_error)
      end

      it "keeps the order, inventory, coupon slot, and cart reserved while reconciliation is pending" do
        params = valid_order_params.deep_merge(order: { coupon_code: coupon.code })

        expect {
          post checkout_path, params: params
        }.not_to have_enqueued_mail(OrderMailer, :confirmation)

        order = Order.last
        expect(order).to be_pending
        expect(order.stripe_checkout_session_id).to be_blank
        expect(order.inventory_movements.reload.sole).to be_reservation
        expect(variant.reload.stock).to eq(8)
        expect(coupon).not_to be_valid_for_use
        expect(Cart.find_by(user: nil).cart_items).not_to be_empty
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("We&#39;re confirming your payment session. Please try again shortly.")
      end
    end

    context "with a Stripe API connection error" do
      let(:stripe_error) { Stripe::APIConnectionError.new("Connection lost") }

      include_examples "an indeterminate Stripe Checkout failure"
    end

    context "with a Stripe API error" do
      let(:stripe_error) { Stripe::APIError.new("Ambiguous Stripe response") }

      include_examples "an indeterminate Stripe Checkout failure"
    end

    context "when the returned Stripe session ID cannot be persisted" do
      let(:coupon) { create(:coupon, usage_limit: 1) }

      before do
        setup_cart(quantity: 2)
        allow(Stripe::Coupon).to receive(:create).and_return(double("Stripe::Coupon", id: "coupon_test_fake"))
        allow(Stripe::Checkout::Session).to receive(:create).and_return(fake_stripe_session)
        allow_any_instance_of(Order).to receive(:update!)
          .with(stripe_checkout_session_id: "cs_test_fake")
          .and_raise(ActiveRecord::ActiveRecordError, "write failed")
      end

      it "keeps the order and reservations pending for webhook reconciliation" do
        params = valid_order_params.deep_merge(order: { coupon_code: coupon.code })

        post checkout_path, params: params

        order = Order.last
        expect(order).to be_pending
        expect(order.stripe_checkout_session_id).to be_blank
        expect(order.inventory_movements.reload.sole).to be_reservation
        expect(order.inventory_movements.release).to be_empty
        expect(variant.reload.stock).to eq(8)
        expect(coupon).not_to be_valid_for_use
        expect(Cart.find_by(user: nil).cart_items).not_to be_empty
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("We&#39;re confirming your payment session. Please try again shortly.")
      end
    end

    context "with a discounted checkout" do
      let(:coupon) { create(:coupon, discount_type: :percentage, value: 10) }

      before do
        setup_cart
        allow(Stripe::Checkout::Session).to receive(:create).and_return(fake_stripe_session)
      end

      it "creates the Stripe coupon with an order-specific idempotency key" do
        expect(Stripe::Coupon).to receive(:create) do |coupon_params, request_options|
          order = Order.last
          expect(coupon_params).to include(amount_off: 500_000, currency: "usd", duration: "once")
          expect(request_options).to eq(idempotency_key: "checkout-coupon-order-#{order.id}")
          double("Stripe::Coupon", id: "coupon_test_fake")
        end

        params = valid_order_params.deep_merge(order: { coupon_code: coupon.code })
        post checkout_path, params: params

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

    context "when a submitted coupon is no longer available" do
      let(:coupon) { create(:coupon, usage_limit: 1) }

      before do
        setup_cart
        create(:order, coupon: coupon, status: :pending)
      end

      it "shows a clear error without creating an order or reserving inventory" do
        params = valid_order_params.deep_merge(order: { coupon_code: coupon.code })
        movement_count = InventoryMovement.count

        expect {
          post checkout_path, params: params
        }.not_to change(Order, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Coupon is no longer available")
        expect(InventoryMovement.count).to eq(movement_count)
        expect(variant.reload.stock).to eq(10)
      end
    end
  end

  describe "GET /checkout/success" do
    it "does not expose an order by its sequential ID" do
      order = create(:order, customer_name: "Private Customer")

      get "/checkout/success", params: { order_id: order.id }

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include("Private Customer")
    end
  end

  describe "GET /checkout/payment_success" do
    it "renders the payment success page when Stripe session matches an order" do
      order = create(:order, customer_name: "Stripe Customer", stripe_checkout_session_id: "cs_test_abc")
      stripe_session = double("Stripe::Checkout::Session", id: "cs_test_abc", payment_status: "paid")
      allow(Stripe::Checkout::Session).to receive(:retrieve).with("cs_test_abc").and_return(stripe_session)

      get payment_success_checkout_path(session_id: "cs_test_abc")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Stripe Customer")
    end

    it "ignores an order_id that points to another order" do
      order = create(:order, customer_name: "Stripe Customer", stripe_checkout_session_id: "cs_test_abc")
      other_order = create(:order, customer_name: "Private Customer")
      stripe_session = double("Stripe::Checkout::Session", id: order.stripe_checkout_session_id, payment_status: "paid")
      allow(Stripe::Checkout::Session).to receive(:retrieve).with("cs_test_abc").and_return(stripe_session)

      get payment_success_checkout_path(session_id: "cs_test_abc", order_id: other_order.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Stripe Customer")
      expect(response.body).not_to include("Private Customer")
    end

    it "does not mark the order paid or clear the cart" do
      setup_cart
      cart = Cart.find_by(user: nil)
      order = create(:order, cart: cart, stripe_checkout_session_id: "cs_test_abc")
      stripe_session = double("Stripe::Checkout::Session", id: "cs_test_abc", payment_status: "paid")
      allow(Stripe::Checkout::Session).to receive(:retrieve).with("cs_test_abc").and_return(stripe_session)

      get payment_success_checkout_path(session_id: "cs_test_abc")

      expect(order.reload).to be_pending
      expect(cart.cart_items.reload).not_to be_empty
    end

    it "returns not found when the Stripe session is not paid" do
      order = create(:order, stripe_checkout_session_id: "cs_test_unpaid")
      stripe_session = double("Stripe::Checkout::Session", id: "cs_test_unpaid", payment_status: "unpaid")
      allow(Stripe::Checkout::Session).to receive(:retrieve).with("cs_test_unpaid").and_return(stripe_session)

      get payment_success_checkout_path(session_id: order.stripe_checkout_session_id)

      expect(response).to have_http_status(:not_found)
    end

    it "returns not found for an unknown Stripe session" do
      allow(Stripe::Checkout::Session).to receive(:retrieve).with("cs_test_unknown")
        .and_raise(Stripe::InvalidRequestError.new("No such checkout session", "session_id"))

      get payment_success_checkout_path(session_id: "cs_test_unknown")

      expect(response).to have_http_status(:not_found)
    end
  end
end
