class FilterGroup < ApplicationRecord
  has_many :filter_options, dependent: :destroy

  extend FriendlyId
  friendly_id :name, use: [ :slugged, :history ]

  validates :name, presence: true

  scope :ordered, -> { order(:position, :name) }
end
