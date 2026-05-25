class Collection < ApplicationRecord
  has_many :collection_memberships, dependent: :destroy
  has_many :products, -> { published }, through: :collection_memberships

  extend FriendlyId
  friendly_id :name, use: [ :slugged, :history ]

  scope :featured_for_nav, -> { where(active: true).limit(4) }

  validates :name, presence: true
end
