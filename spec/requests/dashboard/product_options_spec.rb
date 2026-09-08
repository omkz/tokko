require "rails_helper"

RSpec.describe "Dashboard product options", type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    post session_path, params: { email_address: admin.email_address, password: "password123" }
  end

  def build_option(product, name, values, position:)
    option = product.product_options.create!(name: name, position: position)
    values.each_with_index do |value, index|
      option.product_option_values.create!(value: value, position: index + 1)
    end
    option
  end

  describe "DELETE /dashboard/product_options/:id" do
    it "blocks removal when two active variants would become duplicates and leaves everything untouched" do
      product = create(:product, name: "Tee")
      build_option(product, "Color", %w[Black], position: 1)
      size = build_option(product, "Size", %w[S M], position: 2)
      product.generate_variants!

      variants = product.product_variants.order(:title).to_a
      vov_snapshot = VariantOptionValue.order(:id).pluck(:id, :product_variant_id, :product_option_value_id)
      counts = -> { [ ProductOption.count, ProductOptionValue.count, VariantOptionValue.count, ProductVariant.count ] }
      before_counts = counts.call

      delete dashboard_product_option_path(id: size.id)

      expect(counts.call).to eq(before_counts)
      expect(response).to redirect_to(edit_dashboard_product_path(product))
      expect(flash[:alert]).to eq(
        "Cannot remove this option because multiple active variants would become duplicates. Archive or remove conflicting variants first."
      )

      expect(ProductOption.exists?(size.id)).to be(true)
      expect(size.product_option_values.reload.pluck(:value)).to contain_exactly("S", "M")
      expect(VariantOptionValue.order(:id).pluck(:id, :product_variant_id, :product_option_value_id)).to eq(vov_snapshot)
      expect(product.product_variants.order(:title).to_a).to eq(variants)
    end

    it "blocks removal of the last option when multiple active variants would collapse to empty" do
      product = create(:product, name: "Tee")
      color = build_option(product, "Color", %w[Black White], position: 1)
      product.generate_variants!

      expect {
        delete dashboard_product_option_path(id: color.id)
      }.not_to change { [ ProductOption.count, VariantOptionValue.count ] }

      expect(flash[:alert]).to be_present
      expect(ProductOption.exists?(color.id)).to be(true)
    end

    it "removes the option when only one active variant results" do
      product = create(:product, name: "Tee")
      build_option(product, "Color", %w[Black], position: 1)
      size = build_option(product, "Size", %w[S], position: 2)
      product.generate_variants!

      expect {
        delete dashboard_product_option_path(id: size.id)
      }.to change(ProductOption, :count).by(-1)

      expect(response).to redirect_to(edit_dashboard_product_path(product))
      expect(flash[:notice]).to eq("Option removed")
      expect(ProductOption.exists?(size.id)).to be(false)
    end

    # Note: the "inactive variants don't cause false-positive collisions" case is
    # covered at the model level in spec/models/product_option_spec.rb. Exercising
    # it through the controller would delete a multi-value option, whose existing
    # dependent-destroy cascade trips Prosopite (a pre-existing N+1 unrelated to
    # the collision guard).

    it "leaves existing order history untouched when removal is blocked" do
      product = create(:product, name: "Tee")
      build_option(product, "Color", %w[Black], position: 1)
      size = build_option(product, "Size", %w[S M], position: 2)
      product.generate_variants!
      purchased_variant = product.product_variants.find_by!(title: "Black / S")
      order_item = create(:order_item, product_variant: purchased_variant)

      delete dashboard_product_option_path(id: size.id)

      expect(flash[:alert]).to be_present
      expect(order_item.reload.product_variant).to eq(purchased_variant)
      expect(purchased_variant.reload.product_option_values.pluck(:value)).to contain_exactly("Black", "S")
    end
  end
end
