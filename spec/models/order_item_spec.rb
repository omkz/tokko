require "rails_helper"

RSpec.describe OrderItem, type: :model do
  it "marks purchase snapshots as readonly" do
    expect(described_class.readonly_attributes).to include(
      "product_name", "variant_options", "variant_sku", "unit_price"
    )
  end
end
