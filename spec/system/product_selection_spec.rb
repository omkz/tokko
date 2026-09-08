require "rails_helper"

RSpec.describe "Product variant selection", type: :system, js: true do
  def create_product_with_variant(price: 29.99, stock: 10, active: true)
    product = create(:product, status: :active)
    product.product_variants.destroy_all

    size = product.product_options.create!(name: "Size", position: 1)
    medium = size.product_option_values.create!(value: "M", position: 1)
    size.product_option_values.create!(value: "L", position: 2)

    variant = create(:product_variant, product: product, price: price, stock: stock, active: active)
    VariantOptionValue.create!(product_variant: variant, product_option_value: medium)

    [ product, variant ]
  end

  it "clears an unavailable combination and restores the valid variant when reselected" do
    product, variant = create_product_with_variant

    visit product_path(product)

    expect(page).to have_button("Add to Cart", disabled: false)
    expect(variant_id_field.value).to eq(variant.id.to_s)
    expect(price_element).to have_text("$29.99")
    expect(stock_badge).to have_text("IN STOCK")

    find('button[data-option="Size"][data-value="L"]').click

    expect(page).to have_button("Unavailable", disabled: true)
    expect(variant_id_field.value).to eq("")
    expect(price_element).to have_text("—")
    expect(stock_badge).to have_text("UNAVAILABLE")
    expect(quantity_field.value).to eq("1")
    expect(quantity_field["data-max"]).to eq("0")
    find('button[data-action="click->product-selection#increment"]').click
    expect(quantity_field.value).to eq("1")

    find('button[data-option="Size"][data-value="M"]').click

    expect(page).to have_button("Add to Cart", disabled: false)
    expect(variant_id_field.value).to eq(variant.id.to_s)
    expect(price_element).to have_text("$29.99")
    expect(stock_badge).to have_text("IN STOCK")
    expect(quantity_field["data-max"]).to eq("10")
  end

  it "keeps an inactive matching variant unavailable" do
    product, variant = create_product_with_variant(active: false)

    visit product_path(product)

    expect(page).to have_button("Out of Stock", disabled: true)
    expect(variant_id_field.value).to eq(variant.id.to_s)
    expect(stock_badge).to have_text("OUT OF STOCK")
  end

  it "keeps a zero-stock matching variant unavailable" do
    product, variant = create_product_with_variant(stock: 0)

    visit product_path(product)

    expect(page).to have_button("Out of Stock", disabled: true)
    expect(variant_id_field.value).to eq(variant.id.to_s)
    expect(stock_badge).to have_text("OUT OF STOCK")
    expect(quantity_field["data-max"]).to eq("0")
  end

  def variant_id_field
    find('input[name="variant_id"]', visible: :all)
  end

  def price_element
    find('[data-product-selection-target="price"]')
  end

  def stock_badge
    find('[data-product-selection-target="stockBadge"]')
  end

  def quantity_field
    find('[data-product-selection-target="quantity"]')
  end
end
