require "rails_helper"

RSpec.describe ProductVariant, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:sku) }
    it { is_expected.to validate_presence_of(:price) }
    it { is_expected.to validate_presence_of(:stock) }
    it { is_expected.to validate_numericality_of(:stock).is_greater_than_or_equal_to(0) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:product) }
    it { is_expected.to have_many(:inventory_movements).dependent(:destroy) }
    it { is_expected.to have_many(:order_items) }
  end

  describe "deletion" do
    it "destroys a variant with no order items" do
      variant = create(:product_variant)

      expect { variant.destroy! }.to change(ProductVariant, :count).by(-1)
      expect(variant).to be_destroyed
    end

    it "does not destroy a variant that has been purchased" do
      variant = create(:product_variant, active: true)
      create(:order_item, product_variant: variant)

      expect { variant.destroy }.not_to change(ProductVariant, :count)

      expect(variant.reload).to be_active
      expect(variant.errors[:base]).to be_present
    end

    it "preserves historical order data when the catalog item is archived" do
      variant = create(:product_variant, active: true)
      order_item = create(:order_item, product_variant: variant)
      snapshots = order_item.attributes.slice("product_name", "variant_options", "variant_sku", "unit_price")

      expect { variant.archive! }.not_to change(OrderItem, :count)
      variant.product.archive!

      expect(variant.reload).not_to be_active
      expect(order_item.reload.product_variant_id).to eq(variant.id)
      expect(order_item.product_variant).to eq(variant.reload)
      expect(order_item.attributes.slice(*snapshots.keys)).to eq(snapshots)
    end

    it "raises when destroy! is called on a purchased variant" do
      variant = create(:product_variant, active: true)
      order_item = create(:order_item, product_variant: variant)

      expect { variant.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)

      expect(variant.reload).to be_active
      expect(order_item.reload).to be_persisted
    end
  end

  describe "#out_of_stock?" do
    it "returns true when stock is 0" do
      variant = build(:product_variant, stock: 0)
      expect(variant.out_of_stock?).to be true
    end

    it "returns false when stock is positive" do
      variant = build(:product_variant, stock: 5)
      expect(variant.out_of_stock?).to be false
    end
  end

  describe "#purchasable?" do
    it "is true for an active variant of an active product" do
      variant = build(:product_variant, active: true, product: build(:product, status: :active))

      expect(variant).to be_purchasable
    end

    it "is false for an inactive variant of an active product" do
      variant = build(:product_variant, active: false, product: build(:product, status: :active))

      expect(variant).not_to be_purchasable
    end

    it "is false for an active variant of a draft product" do
      variant = build(:product_variant, active: true, product: build(:product, status: :draft))

      expect(variant).not_to be_purchasable
    end

    it "is false for an active variant of an archived product" do
      variant = build(:product_variant, active: true, product: build(:product, status: :archived))

      expect(variant).not_to be_purchasable
    end
  end

  describe "DB constraint: stock_non_negative" do
    it "raises CheckViolation when stock is set negative via raw SQL" do
      variant = create(:product_variant, stock: 0)
      expect {
        variant.update_columns(stock: -1)
      }.to raise_error(ActiveRecord::CheckViolation)
    end
  end
end
