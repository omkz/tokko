require "rails_helper"

RSpec.describe OrderMailer, type: :mailer do
  it "renders item snapshots instead of current catalog text" do
    variant = create(:product_variant)
    order = create(:order)
    create(
      :order_item,
      order: order,
      product_variant: variant,
      product_name: "Purchased Shirt",
      variant_options: "Black / Large",
      variant_sku: "SHIRT-BLK-L"
    )
    variant.product.update!(name: "Renamed Shirt")
    variant.update!(title: "White / Small", sku: "SHIRT-WHT-S")

    mail = described_class.confirmation(order)
    bodies = [ mail.html_part.body.decoded, mail.text_part.body.decoded ]

    bodies.each do |body|
      expect(body).to include("Purchased Shirt", "Black / Large", "SHIRT-BLK-L")
      expect(body).not_to include("Renamed Shirt", "White / Small", "SHIRT-WHT-S")
    end
  end
end
