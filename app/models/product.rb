class Product < ApplicationRecord
  has_many :product_options,
           -> { order(:position) },
           dependent: :destroy

  has_many :product_variants,
           dependent: :destroy

  has_many_attached :images
  has_many :collection_memberships, dependent: :destroy
  has_many :collections, through: :collection_memberships

  validates :name, presence: true

  scope :search, ->(query) {
    return all if query.blank?
    where("name ILIKE ? OR description ILIKE ?", "%#{query}%", "%#{query}%")
  }

  after_create :create_default_variant

  # Generate all variant combinations from current options.
  # Skips combinations that already exist.
  # Removes the default "Default Title" variant if real options exist.
  def generate_variants!
    option_value_groups = product_options
                            .includes(:product_option_values)
                            .map { |o| o.product_option_values.to_a }

    # If no options defined, ensure single default variant
    if option_value_groups.empty?
      create_default_variant
      return
    end

    # Remove "Default Title" placeholder variant if it exists
    product_variants.where(title: "Default Title").destroy_all

    combinations = cartesian_product(option_value_groups)

    combinations.each do |combo|
      combo   = Array(combo)
      title   = combo.map(&:value).join(" / ")
      val_ids = combo.map(&:id).sort

      # Find all existing variants and check if this combo is covered
      # by comparing the sorted set of option_value ids
      already_exists = product_variants.includes(:variant_option_values).any? do |v|
        existing_ids = v.variant_option_values.map(&:product_option_value_id).sort
        existing_ids == val_ids
      end

      next if already_exists

      variant = product_variants.create!(
        title:  title,
        sku:    generate_sku,
        price:  0,
        stock:  0,
        active: true
      )

      combo.each do |option_value|
        variant.variant_option_values.create!(
          product_option_value: option_value
        )
      end
    end
  end

  private

  def create_default_variant
    return if product_variants.exists?

    product_variants.create!(
      title:  "Default Title",
      sku:    SecureRandom.hex(4).upcase,
      price:  0,
      stock:  0,
      active: true
    )
  end

  def generate_sku
    prefix = name.parameterize.upcase.gsub("-", "")[0..5]
    "#{prefix}-#{SecureRandom.hex(3).upcase}"
  end

  def cartesian_product(arrays)
    arrays.reduce([[]]) do |acc, group|
      acc.flat_map { |combo| group.map { |item| combo + [item] } }
    end
  end
end
