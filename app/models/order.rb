class Order < ApplicationRecord
  has_many :order_items, dependent: :destroy
  has_many :product_variants, through: :order_items

  enum :status, {
    pending: 0,
    paid: 1,
    shipped: 2,
    completed: 3,
    cancelled: 4
  }, default: :pending

  scope :successful, -> { where(status: [ :paid, :shipped, :completed ]) }

  def self.total_revenue
    successful.sum(:total_price)
  end

  def self.revenue_on(date)
    where(created_at: date.beginning_of_day..date.end_of_day).successful.sum(:total_price)
  end

  validates :customer_name, :customer_email, :shipping_address, presence: true
  validates :customer_email, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Builds and persists an order from a cart inside a single locked transaction.
  # Returns [order, stock_errors]. If stock_errors is empty and order.persisted?,
  # the order was created successfully.
  def self.create_from_cart!(cart, attributes)
    order = new(attributes)
    stock_errors = []
    sorted_items = cart.cart_items.includes(product_variant: :product).sort_by(&:product_variant_id)

    transaction do
      variant_ids = sorted_items.map(&:product_variant_id)
      locked_variants = ProductVariant.lock.includes(:product).where(id: variant_ids).index_by(&:id)

      sorted_items.each do |item|
        variant = locked_variants[item.product_variant_id]
        next if variant.stock >= item.quantity

        stock_errors << if variant.stock == 0
          "#{variant.product.name} (#{variant.option_text}) is out of stock"
        else
          "#{variant.product.name} (#{variant.option_text}) only has #{variant.stock} left in stock"
        end
      end

      raise ActiveRecord::Rollback if stock_errors.any?

      order.total_price = cart.total_price
      order.status = :pending
      raise ActiveRecord::Rollback unless order.save

      sorted_items.each do |item|
        variant = locked_variants[item.product_variant_id]
        order_item = order.order_items.create!(
          product_variant: variant,
          quantity: item.quantity,
          unit_price: variant.price
        )
        InventoryMovement.create!(
          product_variant: variant,
          quantity: -item.quantity,
          reason: :sale,
          order_item: order_item
        )
      end
    end

    [ order, stock_errors ]
  end
end
