require "rails_helper"

RSpec.describe Product, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:category).optional }
    it { is_expected.to have_many(:product_variants).dependent(:destroy) }
    it { is_expected.to have_many(:product_options).dependent(:destroy) }
    it { is_expected.to have_many(:collection_memberships).dependent(:destroy) }
    it { is_expected.to have_many(:collections).through(:collection_memberships) }
    it { is_expected.to have_many(:product_filter_options).dependent(:destroy) }
    it { is_expected.to have_many(:filter_options).through(:product_filter_options) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe "status enum" do
    it "defaults to draft" do
      expect(Product.new.status).to eq("draft")
    end

    it { is_expected.to define_enum_for(:status).with_values(draft: "draft", active: "active", archived: "archived").backed_by_column_of_type(:string) }
  end

  describe "deletion" do
    it "destroys a product with no historical order items" do
      product = create(:product)

      expect { product.destroy! }.to change(Product, :count).by(-1)
      expect(product).to be_destroyed
    end

    it "does not destroy a product or its variants when it has order history" do
      product = create(:product, status: :active)
      variant = product.product_variants.first
      order_item = create(:order_item, product_variant: variant)

      expect { product.destroy }.not_to change(Product, :count)

      expect(product.reload).to be_active
      expect(variant.reload).to be_persisted
      expect(order_item.reload.product_variant).to eq(variant)
    end
  end

  describe "after_create callback" do
    it "creates a default variant on product creation" do
      product = create(:product)
      expect(product.product_variants.count).to eq(1)
      expect(product.product_variants.first.title).to eq("Default Title")
    end

    it "does not create a second default variant if one already exists" do
      product = create(:product)
      expect { product.send(:create_default_variant) }.not_to change(ProductVariant, :count)
    end
  end

  describe "#generate_variants!" do
    def create_product_option(product, name, values, position: 1)
      option = product.product_options.create!(name: name, position: position)
      values.map.with_index do |value, index|
        option.product_option_values.create!(value: value, position: index + 1)
      end
    end

    let(:product) { create(:product, name: "Everyday Shirt") }

    it "keeps exactly one default variant when there are no options" do
      product.generate_variants!

      expect(product.product_variants.reload.pluck(:title)).to eq([ "Default Title" ])
    end

    it "generates one variant for each value of one option" do
      create_product_option(product, "Color", %w[Black White])

      product.generate_variants!

      variants = product.product_variants.reload
      expect(variants.count).to eq(2)
      expect(variants.pluck(:title)).to contain_exactly("Black", "White")
      expect(variants).to all(have_attributes(price: 0, stock: 0, active: true))
    end

    it "generates every combination with the correct titles for multiple options" do
      create_product_option(product, "Color", %w[Black White], position: 1)
      create_product_option(product, "Size", %w[S M L], position: 2)

      product.generate_variants!

      expect(product.product_variants.reload.pluck(:title)).to contain_exactly(
        "Black / S", "Black / M", "Black / L",
        "White / S", "White / M", "White / L"
      )
    end

    it "associates every generated variant with its selected option values" do
      colors = create_product_option(product, "Color", %w[Black White], position: 1)
      sizes = create_product_option(product, "Size", %w[S M], position: 2)

      product.generate_variants!

      black_medium = product.product_variants.find_by!(title: "Black / M")
      expect(black_medium.product_option_value_ids).to contain_exactly(colors.first.id, sizes.second.id)
    end

    it "does not duplicate variants or option relationships when called twice" do
      create_product_option(product, "Color", %w[Black White])
      product.generate_variants!
      variant_ids = product.product_variants.order(:id).ids
      relationship_ids = VariantOptionValue.where(product_variant_id: variant_ids).order(:id).ids

      product.generate_variants!

      expect(product.product_variants.order(:id).ids).to eq(variant_ids)
      expect(VariantOptionValue.where(product_variant_id: variant_ids).order(:id).ids).to eq(relationship_ids)
    end

    it "keeps the default variant when an option has no values" do
      default_variant = product.product_variants.sole
      product.product_options.create!(name: "Color", position: 1)

      product.generate_variants!

      expect(product.product_variants.reload).to contain_exactly(default_variant)
      expect(default_variant.reload.title).to eq("Default Title")
    end

    it "keeps an existing combination and adds only missing combinations" do
      colors = create_product_option(product, "Color", %w[Black White])
      existing_variant = product.product_variants.create!(
        title: "Black",
        sku: "SHIRT-BLACK",
        price: 0,
        stock: 0,
        active: true
      )
      existing_variant.variant_option_values.create!(product_option_value: colors.first)

      product.generate_variants!

      expect(product.product_variants.reload.pluck(:title)).to contain_exactly("Black", "White")
      expect(product.product_variants).to include(existing_variant)
      expect(VariantOptionValue.where(product_variant: product.product_variants).count).to eq(2)
    end
  end

  describe ".published scope" do
    it "returns only active products" do
      active   = create(:product, status: :active)
      draft    = create(:product, status: :draft)
      archived = create(:product, status: :archived)

      ids = Product.published.pluck(:id)
      expect(ids).to include(active.id)
      expect(ids).not_to include(draft.id, archived.id)
    end
  end

  describe ".search" do
    let!(:shirt) { create(:product, name: "Blue Shirt", description: "A cotton shirt") }
    let!(:pants) { create(:product, name: "Black Pants", description: "Slim fit trousers") }

    it "returns all products when query is blank" do
      expect(Product.search("").pluck(:id)).to include(shirt.id, pants.id)
    end

    it "matches by name (case-insensitive)" do
      expect(Product.search("shirt").pluck(:id)).to include(shirt.id)
      expect(Product.search("SHIRT").pluck(:id)).to include(shirt.id)
    end

    it "matches by description" do
      expect(Product.search("trousers").pluck(:id)).to include(pants.id)
    end

    it "excludes non-matching products" do
      expect(Product.search("shirt").pluck(:id)).not_to include(pants.id)
    end
  end

  describe ".sort_by_param" do
    let!(:cheap)     { create(:product).tap { |p| p.product_variants.first.update!(price: 10_000) } }
    let!(:expensive) { create(:product).tap { |p| p.product_variants.first.update!(price: 100_000) } }

    it "sorts by price ascending" do
      ids = Product.sort_by_param("price_asc").pluck(:id)
      expect(ids.index(cheap.id)).to be < ids.index(expensive.id)
    end

    it "sorts by price descending" do
      ids = Product.sort_by_param("price_desc").pluck(:id)
      expect(ids.index(expensive.id)).to be < ids.index(cheap.id)
    end

    it "defaults to newest first" do
      ids = Product.sort_by_param(nil).pluck(:id)
      expect(ids.index(expensive.id)).to be < ids.index(cheap.id)
    end
  end

  describe ".in_category scope" do
    let(:parent)   { create(:category) }
    let(:child)    { create(:category, parent: parent) }
    let!(:product_in_parent) { create(:product, category: parent) }
    let!(:product_in_child)  { create(:product, category: child) }
    let!(:product_elsewhere) { create(:product) }

    it "includes products in the category and its descendants" do
      ids = Product.in_category(parent).pluck(:id)
      expect(ids).to include(product_in_parent.id, product_in_child.id)
      expect(ids).not_to include(product_elsewhere.id)
    end
  end

  describe "#related_products" do
    let(:collection) { create(:collection) }
    let!(:product)   { create(:product, :with_collection) }
    let!(:related)   { create(:product) }
    let!(:unrelated) { create(:product) }

    before do
      collection = product.collections.first
      collection.products << related
    end

    it "returns products in the same collection" do
      ids = product.related_products(10).pluck(:id)
      expect(ids).to include(related.id)
    end

    it "excludes the product itself" do
      ids = product.related_products(10).pluck(:id)
      expect(ids).not_to include(product.id)
    end

    it "excludes unrelated products" do
      ids = product.related_products(10).pluck(:id)
      expect(ids).not_to include(unrelated.id)
    end

    it "respects the limit" do
      shared_collection = product.collections.first
      Prosopite.pause
      5.times { shared_collection.products << create(:product) }
      Prosopite.resume
      expect(product.related_products(3).count).to eq(3)
    end
  end
end
