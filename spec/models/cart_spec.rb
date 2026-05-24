require "rails_helper"

RSpec.describe Cart, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to have_many(:cart_items).dependent(:destroy) }
    it { is_expected.to have_many(:product_variants).through(:cart_items) }
  end

  describe "validations" do
    it "enforces token uniqueness at the DB level" do
      existing = create(:cart)
      duplicate = build(:cart, token: existing.token)
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "token auto-generation" do
    it "generates a token before create" do
      cart = Cart.create!(expires_at: 30.days.from_now)
      expect(cart.token).to be_present
    end

    it "does not overwrite an existing token" do
      cart = Cart.create!(token: "mytoken", expires_at: 30.days.from_now)
      expect(cart.token).to eq("mytoken")
    end
  end

  describe "#item_count" do
    it "returns the sum of all item quantities" do
      cart = create(:cart)
      create(:cart_item, cart: cart, quantity: 2)
      create(:cart_item, cart: cart, quantity: 3)
      expect(cart.item_count).to eq(5)
    end

    it "returns 0 for an empty cart" do
      cart = create(:cart)
      expect(cart.item_count).to eq(0)
    end
  end

  describe "#total_price" do
    it "returns the sum of price * quantity for all items" do
      cart = create(:cart)
      variant = create(:product_variant, price: 100_000)
      create(:cart_item, cart: cart, product_variant: variant, quantity: 3)
      expect(cart.total_price).to eq(300_000)
    end

    it "returns 0 for an empty cart" do
      cart = create(:cart)
      expect(cart.total_price).to eq(0)
    end
  end

  describe "#merge_from" do
    it "moves items from the other cart into self" do
      cart = create(:cart)
      other = create(:cart)
      variant = create(:product_variant)
      create(:cart_item, cart: other, product_variant: variant, quantity: 2)

      cart.merge_from(other)

      expect(cart.cart_items.find_by(product_variant: variant).quantity).to eq(2)
    end

    it "adds quantities when the same variant exists in both carts" do
      variant = create(:product_variant)
      cart = create(:cart)
      other = create(:cart)
      create(:cart_item, cart: cart, product_variant: variant, quantity: 1)
      create(:cart_item, cart: other, product_variant: variant, quantity: 3)

      cart.merge_from(other)

      expect(cart.cart_items.find_by(product_variant: variant).quantity).to eq(4)
    end

    it "destroys the other cart after merging" do
      cart = create(:cart)
      other = create(:cart)
      create(:cart_item, cart: other)

      cart.merge_from(other)

      expect(Cart.exists?(other.id)).to be false
    end

    it "does nothing when called with nil" do
      cart = create(:cart)
      expect { cart.merge_from(nil) }.not_to raise_error
    end

    it "does nothing when called with self" do
      cart = create(:cart)
      create(:cart_item, cart: cart)
      expect { cart.merge_from(cart) }.not_to change { cart.cart_items.count }
    end
  end
end
