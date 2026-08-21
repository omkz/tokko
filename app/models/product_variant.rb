class ProductVariant < ApplicationRecord
  belongs_to :product

  has_many :inventory_movements, dependent: :destroy
  has_many :order_items
  has_many :variant_option_values,
           dependent: :destroy

  has_many :product_option_values,
           through: :variant_option_values

  scope :search_by_product_name, ->(query) {
    return all if query.blank?
    where("products.name ILIKE ?", "%#{query}%")
  }

  validates :sku, presence: true
  validates :price, presence: true
  validates :stock, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_destroy :prevent_destroy_with_order_history, prepend: true

  def destroyable?
    !order_items.exists?
  end

  def archive!
    update!(active: false)
  end

  def destroy_or_archive!
    if destroyable?
      destroy!
      :destroyed
    else
      archive!
      :archived
    end
  end

  def out_of_stock?
    stock <= 0
  end

  def option_text
    values = product_option_values.map(&:value)

    return title if values.empty?

    values.join(" / ")
  end

  private

  def prevent_destroy_with_order_history
    return if destroyable?

    errors.add(:base, "Purchased variants cannot be destroyed")
    throw :abort
  end
end
