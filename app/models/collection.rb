class Collection < ApplicationRecord
  has_many :collection_memberships, dependent: :destroy
  has_many :products, through: :collection_memberships

  validates :name, presence: true
  before_validation :generate_slug, if: :name_changed?

  private

  def generate_slug
    self.slug = name.parameterize if name.present?
  end
end
