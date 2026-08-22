require "rails_helper"

RSpec.describe Order, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:order_items).dependent(:destroy) }
    it { is_expected.to have_many(:product_variants).through(:order_items) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:customer_name) }
    it { is_expected.to validate_presence_of(:customer_email) }
    it { is_expected.to validate_presence_of(:shipping_address) }

    it "is invalid with a malformed email" do
      order = build(:order, customer_email: "not-an-email")
      expect(order).not_to be_valid
    end
  end

  describe "status enum" do
    it "defaults to pending" do
      expect(Order.new.status).to eq("pending")
    end

    it { is_expected.to define_enum_for(:status).with_values(pending: 0, paid: 1, shipped: 2, completed: 3, cancelled: 4) }
  end

  describe ".successful scope" do
    it "includes paid, shipped, and completed orders" do
      paid      = create(:order, status: :paid)
      shipped   = create(:order, status: :shipped)
      completed = create(:order, status: :completed)
      pending   = create(:order, status: :pending)
      cancelled = create(:order, status: :cancelled)

      result_ids = Order.successful.pluck(:id)
      expect(result_ids).to include(paid.id, shipped.id, completed.id)
      expect(result_ids).not_to include(pending.id, cancelled.id)
    end
  end

  describe ".total_revenue" do
    it "sums total_price of successful orders only" do
      create(:order, status: :paid, total_price: 100_000)
      create(:order, status: :completed, total_price: 50_000)
      create(:order, status: :pending, total_price: 200_000)
      create(:order, status: :cancelled, total_price: 75_000)

      expect(Order.total_revenue).to eq(150_000)
    end
  end

  describe ".create_from_cart!" do
    let(:cart) { create(:cart) }
    let(:variant) { create(:product_variant, price: 50_000, stock: 10) }

    let(:valid_attributes) do
      {
        customer_name: "Budi",
        customer_email: "budi@example.com",
        shipping_address: "Jakarta"
      }
    end

    context "with sufficient stock" do
      before { create(:cart_item, cart: cart, product_variant: variant, quantity: 2) }

      it "returns a persisted order" do
        order, errors = Order.create_from_cart!(cart, valid_attributes)
        expect(order).to be_persisted
        expect(errors).to be_empty
      end

      it "sets total_price from the cart" do
        order, _ = Order.create_from_cart!(cart, valid_attributes)
        expect(order.total_price).to eq(100_000)
      end

      it "sets status to pending" do
        order, _ = Order.create_from_cart!(cart, valid_attributes)
        expect(order.status).to eq("pending")
      end

      it "creates order items with catalog snapshots" do
        order, _ = Order.create_from_cart!(cart, valid_attributes)
        item = order.order_items.first
        expect(item).to have_attributes(
          quantity: 2,
          product_name: variant.product.name,
          variant_options: variant.option_text,
          variant_sku: variant.sku,
          unit_price: variant.price
        )
      end

      it "preserves snapshots after the catalog changes" do
        option = ProductOption.create!(product: variant.product, name: "Color", position: 1)
        option_value = ProductOptionValue.create!(product_option: option, value: "Black", position: 1)
        VariantOptionValue.create!(product_variant: variant, product_option_value: option_value)
        order, _ = Order.create_from_cart!(cart, valid_attributes)

        item = order.order_items.first
        snapshots = item.attributes.slice("product_name", "variant_options", "variant_sku", "unit_price")

        variant.product.update!(name: "Renamed Product")
        variant.update!(sku: "NEW-SKU", price: 75_000)
        option_value.update!(value: "White")

        expect(item.reload.attributes.slice(*snapshots.keys)).to eq(snapshots)
      end

      it "reserves variant stock" do
        Order.create_from_cart!(cart, valid_attributes)
        expect(variant.reload.stock).to eq(8)
      end

      it "creates a reservation movement" do
        expect {
          Order.create_from_cart!(cart, valid_attributes)
        }.to change(InventoryMovement, :count).by(1)

        movement = InventoryMovement.last
        expect(movement.quantity).to eq(-2)
        expect(movement.reason).to eq("reservation")
      end
    end

    context "with multiple variants" do
      let(:variant2) { create(:product_variant, price: 30_000, stock: 5) }

      before do
        create(:cart_item, cart: cart, product_variant: variant, quantity: 1)
        create(:cart_item, cart: cart, product_variant: variant2, quantity: 3)
      end

      it "creates order items for all variants" do
        order, _ = Order.create_from_cart!(cart, valid_attributes)
        expect(order.order_items.count).to eq(2)
      end

      it "calculates total_price across all items" do
        order, _ = Order.create_from_cart!(cart, valid_attributes)
        expect(order.total_price).to eq(50_000 + 90_000)
      end

      it "decrements stock for each variant" do
        Order.create_from_cart!(cart, valid_attributes)
        expect(variant.reload.stock).to eq(9)
        expect(variant2.reload.stock).to eq(2)
      end
    end

    context "when a variant is out of stock" do
      before { create(:cart_item, cart: cart, product_variant: variant, quantity: 1) }

      it "returns stock errors and does not create an order" do
        variant.update!(stock: 0)
        expect {
          order, errors = Order.create_from_cart!(cart, valid_attributes)
          expect(order).not_to be_persisted
          expect(errors).not_to be_empty
        }.not_to change(Order, :count)
      end
    end

    context "when quantity exceeds stock" do
      before { create(:cart_item, cart: cart, product_variant: variant, quantity: 5) }

      it "returns a stock error message" do
        variant.update!(stock: 3)
        _, errors = Order.create_from_cart!(cart, valid_attributes)
        expect(errors.first).to include("only has 3 left in stock")
      end

      it "does not decrement stock" do
        variant.update!(stock: 3)
        Order.create_from_cart!(cart, valid_attributes)
        expect(variant.reload.stock).to eq(3)
      end
    end

    context "when a variant is no longer purchasable" do
      let(:coupon) { create(:coupon, usage_limit: 1) }

      before do
        create(:cart_item, cart: cart, product_variant: variant, quantity: 2)
        variant.archive!
      end

      it "does not create an order, reserve inventory, or consume coupon capacity" do
        order = nil
        errors = nil

        expect {
          order, errors = Order.create_from_cart!(cart, valid_attributes, coupon_code: coupon.code)
        }.not_to change(Order, :count)

        expect(order).not_to be_persisted
        expect(errors).to contain_exactly("#{variant.product.name} (#{variant.option_text}) is no longer available")
        expect(InventoryMovement.reservation).to be_empty
        expect(variant.reload.stock).to eq(10)
        expect(coupon).to be_valid_for_use
      end
    end

    context "with two competing checkouts" do
      let(:other_cart) { create(:cart) }

      before do
        variant.update!(stock: 1)
        create(:cart_item, cart: cart, product_variant: variant, quantity: 1)
        create(:cart_item, cart: other_cart, product_variant: variant, quantity: 1)
      end

      it "does not reserve more stock than is available" do
        first_order, first_errors = Order.create_from_cart!(cart, valid_attributes)
        second_order, second_errors = Order.create_from_cart!(other_cart, valid_attributes)

        expect(first_order).to be_persisted
        expect(first_errors).to be_empty
        expect(second_order).not_to be_persisted
        expect(second_errors).not_to be_empty
        expect(variant.reload.stock).to eq(0)
        expect(InventoryMovement.reservation.count).to eq(1)
      end
    end

    context "with a usage-limited coupon" do
      let(:coupon) { create(:coupon, usage_limit: 1) }
      let(:other_cart) { create(:cart) }

      before do
        create(:cart_item, cart: cart, product_variant: variant, quantity: 1)
        create(:cart_item, cart: other_cart, product_variant: variant, quantity: 1)
      end

      it "locks the coupon while reserving its usage slot" do
        expect(Coupon).to receive(:lock).and_call_original

        order, errors = Order.create_from_cart!(cart, valid_attributes, coupon_code: coupon.code)

        expect(order).to be_persisted
        expect(errors).to be_empty
      end

      it "allows only one competing checkout to reserve the coupon" do
        first_order, first_errors = Order.create_from_cart!(cart, valid_attributes, coupon_code: coupon.code)
        second_order, second_errors = Order.create_from_cart!(other_cart, valid_attributes, coupon_code: coupon.code)

        expect(first_order).to be_persisted
        expect(first_errors).to be_empty
        expect(second_order).not_to be_persisted
        expect(second_errors).to be_empty
        expect(second_order.errors.full_messages).to include("Coupon is no longer available")
        expect(coupon.orders.pending).to contain_exactly(first_order)
      end

      it "does not create an order or reserve inventory when the coupon is unavailable" do
        create(:order, coupon: coupon, status: :pending)
        movement_count = InventoryMovement.count

        expect {
          order, = Order.create_from_cart!(cart, valid_attributes, coupon_code: coupon.code)
          expect(order.errors.full_messages).to include("Coupon is no longer available")
        }.not_to change(Order, :count)

        expect(InventoryMovement.count).to eq(movement_count)
        expect(variant.reload.stock).to eq(10)
      end
    end

    context "with invalid order attributes" do
      before { create(:cart_item, cart: cart, product_variant: variant, quantity: 1) }

      it "returns an unpersisted order with no stock errors" do
        order, errors = Order.create_from_cart!(cart, { customer_name: "" })
        expect(order).not_to be_persisted
        expect(errors).to be_empty
      end
    end
  end

  describe "#ship!" do
    it "moves a paid order to shipped" do
      order = create(:order, :paid)

      expect(order.ship!).to be true
      expect(order.reload).to be_shipped
    end

    it "does not ship a pending order" do
      order = create(:order)

      expect(order.ship!).to be false
      expect(order.reload).to be_pending
    end

    it "does not ship a cancelled order" do
      order = create(:order, :cancelled)

      expect(order.ship!).to be false
      expect(order.reload).to be_cancelled
    end
  end

  describe "#complete!" do
    it "moves a shipped order to completed" do
      order = create(:order, status: :shipped)

      expect(order.complete!).to be true
      expect(order.reload).to be_completed
    end

    it "does not let a paid order skip directly to completed" do
      order = create(:order, :paid)

      expect(order.complete!).to be false
      expect(order.reload).to be_paid
    end
  end

  describe "Stripe lifecycle transitions" do
    let(:variant) { create(:product_variant, stock: 10) }
    let(:order) { create(:order) }
    let(:item) { create(:order_item, order: order, product_variant: variant, quantity: 2) }

    before do
      create(:inventory_movement, product_variant: variant, order_item: item, quantity: -2, reason: :reservation)
    end

    it "completes payment only from pending" do
      expect(order.complete_payment!).to be true
      expect(order.reload).to be_paid
      expect(order.inventory_movements.reload.sole).to be_sale
    end

    it "expires a pending checkout and releases its reservation exactly once" do
      expect(order.expire_checkout!).to be true
      expect(order.expire_checkout!).to be false
      expect(order.reload).to be_cancelled
      expect(order.inventory_movements.release.sole.quantity).to eq(2)
      expect(variant.reload.stock).to eq(10)
    end

    %w[paid shipped completed cancelled].each do |current_status|
      it "does not expire a #{current_status} order" do
        order.complete_payment! if %w[paid shipped completed].include?(current_status)
        order.ship! if %w[shipped completed].include?(current_status)
        order.complete! if current_status == "completed"
        order.expire_checkout! if current_status == "cancelled"
        movement_count = InventoryMovement.count
        stock = variant.reload.stock

        expect(order.expire_checkout!).to be false
        expect(InventoryMovement.count).to eq(movement_count)
        expect(order.reload.status).to eq(current_status)
        expect(variant.reload.stock).to eq(stock)
      end
    end
  end
end
