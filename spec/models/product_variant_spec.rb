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

  describe "DB constraint: stock_non_negative" do
    it "raises CheckViolation when stock is set negative via raw SQL" do
      variant = create(:product_variant, stock: 0)
      expect {
        variant.update_columns(stock: -1)
      }.to raise_error(ActiveRecord::CheckViolation)
    end
  end
end
