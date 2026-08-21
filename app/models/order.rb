class Order < ApplicationRecord
  has_many :order_items, dependent: :destroy
  has_many :product_variants, through: :order_items
  has_many :inventory_movements, through: :order_items
  belongs_to :coupon, optional: true
  belongs_to :cart, optional: true

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
  def self.create_from_cart!(cart, attributes, coupon_code: nil)
    order = new(attributes)
    stock_errors = []
    sorted_items = cart.cart_items.includes(product_variant: :product).sort_by(&:product_variant_id)

    transaction do
      normalized_coupon_code = coupon_code.to_s.upcase.strip
      coupon = Coupon.lock.find_by(code: normalized_coupon_code) if normalized_coupon_code.present?

      if normalized_coupon_code.present? && !coupon&.valid_for_use?
        message = coupon ? "is no longer available" : "could not be found"
        order.errors.add(:coupon, message)
        raise ActiveRecord::Rollback
      end

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

      subtotal = cart.total_price
      discount = coupon&.discount_for(subtotal) || 0
      order.coupon = coupon
      order.cart = cart
      order.discount_amount = discount
      order.total_price = subtotal - discount
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
          reason: :reservation,
          order_item: order_item
        )
      end
    end

    [ order, stock_errors ]
  end

  def complete_payment!
    with_lock do
      return false unless pending?

      inventory_movements.reservation.update_all(reason: "sale", updated_at: Time.current)
      update!(status: :paid)
      true
    end
  end

  def expire_checkout!
    with_lock do
      return false unless pending?

      reservations = inventory_movements.reservation.includes(:product_variant, :order_item)
        .sort_by { |movement| [ movement.product_variant_id, movement.id ] }

      reservations.each do |reservation|
        InventoryMovement.create!(
          product_variant: reservation.product_variant,
          order_item: reservation.order_item,
          quantity: -reservation.quantity,
          reason: :release
        )
      end

      update!(status: :cancelled)
      true
    end
  end
end
