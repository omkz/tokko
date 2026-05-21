class Category < ApplicationRecord
  # Hierarchy
  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: "parent_id", dependent: :destroy

  # Products
  has_many :products, dependent: :nullify

  # Validations
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  # Callbacks
  before_validation :generate_slug, on: :create
  before_create :set_position

  # Scopes
  scope :roots, -> { where(parent_id: nil) }
  scope :ordered, -> { order(:position, :name) }

  def to_param
    slug
  end

  # Fetch self and all descendants (subcategories) efficiently
  def self_and_descendant_ids
    [id] + children.flat_map(&:self_and_descendant_ids)
  end

  private

  def generate_slug
    self.slug = name.parameterize if name.present? && slug.blank?
  end

  def set_position
    max = Category.where(parent_id: parent_id).maximum(:position) || 0
    self.position = max + 1
  end
end
