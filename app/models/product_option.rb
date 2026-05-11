class ProductOption < ApplicationRecord
  belongs_to :product

  has_many :product_option_values,
           -> { order(:position) },
           dependent: :destroy

  accepts_nested_attributes_for :product_option_values,
                                allow_destroy: true,
                                reject_if: ->(attrs) { attrs["value"].blank? }

  validates :name, presence: true
end
