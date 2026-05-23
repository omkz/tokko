class InventoryMovement < ApplicationRecord
  belongs_to :product_variant
  belongs_to :user, optional: true
  belongs_to :order_item, optional: true

  enum :reason, { restock: "restock", sale: "sale", return: "return", adjustment: "adjustment", damage: "damage" }

  validates :quantity, presence: true, numericality: { other_than: 0 }
  validates :reason, presence: true

  after_create :update_variant_stock

  private

  def update_variant_stock
    product_variant.with_lock do
      product_variant.increment!(:stock, quantity)
    end
  end
end
