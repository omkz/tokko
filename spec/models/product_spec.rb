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
