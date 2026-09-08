class ProductOption < ApplicationRecord
  belongs_to :product

  has_many :product_option_values,
           -> { order(:position) },
           dependent: :destroy

  accepts_nested_attributes_for :product_option_values,
                                allow_destroy: true,
                                reject_if: ->(attrs) { attrs["value"].blank? }

  validates :name, presence: true

  # Removing an option strips its values from every variant via the
  # dependent-destroy chain, but leaves the ProductVariant rows in place.
  # If two or more active variants would then share the same remaining
  # option-value combination, the active variant set becomes ambiguous for
  # storefront selection. Detect that collision before allowing removal.
  def removable_without_variant_collisions?
    excluded_value_ids = product_option_values.ids.to_set

    remaining_combinations = product.product_variants
      .where(active: true)
      .includes(:variant_option_values)
      .map do |variant|
        variant.variant_option_values
               .map(&:product_option_value_id)
               .reject { |id| excluded_value_ids.include?(id) }
               .sort
      end

    remaining_combinations.length == remaining_combinations.uniq.length
  end
end
