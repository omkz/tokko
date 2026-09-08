require "rails_helper"

RSpec.describe ProductOption, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:product) }
    it { is_expected.to have_many(:product_option_values).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe "#removable_without_variant_collisions?" do
    def build_option(product, name, values, position:)
      option = product.product_options.create!(name: name, position: position)
      values.each_with_index do |value, index|
        option.product_option_values.create!(value: value, position: index + 1)
      end
      option
    end

    it "is false when two active variants would collapse to the same remaining combination" do
      product = create(:product, name: "Tee")
      build_option(product, "Color", %w[Black], position: 1)
      size = build_option(product, "Size", %w[S M], position: 2)
      product.generate_variants!

      expect(size.removable_without_variant_collisions?).to be(false)
    end

    it "is false when the last option is removed and multiple active variants would collapse to empty" do
      product = create(:product, name: "Tee")
      color = build_option(product, "Color", %w[Black White], position: 1)
      product.generate_variants!

      expect(color.removable_without_variant_collisions?).to be(false)
    end

    it "is true when only one active variant remains for the resulting combination" do
      product = create(:product, name: "Tee")
      build_option(product, "Color", %w[Black], position: 1)
      size = build_option(product, "Size", %w[S], position: 2)
      product.generate_variants!

      expect(size.removable_without_variant_collisions?).to be(true)
    end

    it "ignores archived/inactive variants when detecting collisions" do
      product = create(:product, name: "Tee")
      build_option(product, "Color", %w[Black], position: 1)
      size = build_option(product, "Size", %w[S M], position: 2)
      product.generate_variants!
      product.product_variants.find_by!(title: "Black / M").update!(active: false)

      expect(size.removable_without_variant_collisions?).to be(true)
    end
  end
end
