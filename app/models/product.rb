class Product < ApplicationRecord
  has_many :product_options,
           -> { order(:position) },
           dependent: :destroy

  has_many :product_variants,
           dependent: :destroy

  has_many_attached :images
  has_many :collection_memberships, dependent: :destroy
  has_many :collections, through: :collection_memberships

  belongs_to :category, optional: true
  has_many :product_filter_options, dependent: :destroy
  has_many :filter_options, through: :product_filter_options

  extend FriendlyId
  friendly_id :name, use: [ :slugged, :history ]

  enum :status, { draft: "draft", active: "active", archived: "archived" }, default: "draft"

  validates :name, presence: true

  # Scopes
  scope :published,    -> { where(status: :active) }
  scope :in_category,  ->(category) { where(category_id: category.self_and_descendant_ids) }

  scope :best_sellers, ->(limit = 4) {
    joins(product_variants: { order_items: :order })
      .where.not(orders: { status: :cancelled })
      .select("products.*, SUM(order_items.quantity) AS total_sold")
      .group("products.id")
      .order("total_sold DESC")
      .limit(limit)
      .includes(images_attachments: :blob)
  }

  scope :filter_by_facets, ->(filters) do
    return all if filters.blank?

    scope = all
    filters.each do |group_slug, option_slugs|
      matching_product_ids = ProductFilterOption.joins(filter_option: :filter_group)
                                                .where(filter_groups: { slug: group_slug }, filter_options: { slug: option_slugs })
                                                .select(:product_id)
      scope = scope.where(id: matching_product_ids)
    end
    scope
  end

  scope :sort_by_param, ->(sort_param) do
    case sort_param
    when "price_asc"
      joins(:product_variants).group("products.id").order("MIN(product_variants.price) ASC")
    when "price_desc"
      joins(:product_variants).group("products.id").order("MIN(product_variants.price) DESC")
    else
      order(created_at: :desc)
    end
  end

  def self.search(query)
    return all if query.blank?
    where("products.name ILIKE ? OR products.description ILIKE ?", "%#{query}%", "%#{query}%")
  end

  after_create :create_default_variant

  def related_products(limit = 4)
    Product.published
           .joins(:collections)
           .where(collections: { id: collection_ids })
           .where.not(id: id)
           .distinct
           .limit(limit)
  end

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
    arrays.reduce([ [] ]) do |acc, group|
      acc.flat_map { |combo| group.map { |item| combo + [ item ] } }
    end
  end
end
