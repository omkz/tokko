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

      it "creates order items with unit_price snapshot" do
        order, _ = Order.create_from_cart!(cart, valid_attributes)
        item = order.order_items.first
        expect(item.quantity).to eq(2)
        expect(item.unit_price).to eq(variant.price)
      end

      it "decrements variant stock" do
        Order.create_from_cart!(cart, valid_attributes)
        expect(variant.reload.stock).to eq(8)
      end

      it "creates an inventory movement" do
        expect {
          Order.create_from_cart!(cart, valid_attributes)
        }.to change(InventoryMovement, :count).by(1)

        movement = InventoryMovement.last
        expect(movement.quantity).to eq(-2)
        expect(movement.reason).to eq("sale")
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

    context "with invalid order attributes" do
      before { create(:cart_item, cart: cart, product_variant: variant, quantity: 1) }

      it "returns an unpersisted order with no stock errors" do
        order, errors = Order.create_from_cart!(cart, { customer_name: "" })
        expect(order).not_to be_persisted
        expect(errors).to be_empty
      end
    end
  end
end
