class Category < ApplicationRecord
  # Hierarchy
  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: "parent_id", dependent: :destroy

  # Products
  has_many :products, dependent: :nullify

  extend FriendlyId
  friendly_id :name, use: [ :slugged, :history ]

  # Validations
  validates :name, presence: true

  # Callbacks
  before_create :set_position

  # Scopes
  scope :roots, -> { where(parent_id: nil) }
  scope :ordered, -> { order(:position, :name) }

  # Fetch self and all descendants (subcategories) efficiently
  def self_and_descendant_ids
    [ id ] + children.flat_map(&:self_and_descendant_ids)
  end

  private

  def set_position
    max = Category.where(parent_id: parent_id).maximum(:position) || 0
    self.position = max + 1
  end
end
