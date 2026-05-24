require "rails_helper"

RSpec.describe CartItem, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:cart) }
    it { is_expected.to belong_to(:product_variant) }
  end

  describe "validations" do
    it { is_expected.to validate_numericality_of(:quantity).is_greater_than(0).only_integer }

    it "is invalid with quantity 0" do
      item = build(:cart_item, quantity: 0)
      expect(item).not_to be_valid
    end

    it "is invalid with negative quantity" do
      item = build(:cart_item, quantity: -1)
      expect(item).not_to be_valid
    end
  end
end
