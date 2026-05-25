class FilterOption < ApplicationRecord
  belongs_to :filter_group
  has_many :product_filter_options, dependent: :destroy
  has_many :products, through: :product_filter_options

  extend FriendlyId
  friendly_id :value, use: [ :slugged, :scoped ], scope: :filter_group

  validates :value, presence: true

  scope :ordered, -> { order(:position, :value) }
end
