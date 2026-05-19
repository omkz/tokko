class Collection < ApplicationRecord
  has_many :collection_memberships, dependent: :destroy
  has_many :products, through: :collection_memberships

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, if: :name_changed?

  def to_param
    slug
  end

  private

  def generate_slug
    self.slug = name.parameterize if name.present?
  end
end