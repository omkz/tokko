class FilterGroup < ApplicationRecord
  has_many :filter_options, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  scope :ordered, -> { order(:position, :name) }

  private

  def generate_slug
    self.slug = name.parameterize if name.present? && slug.blank?
  end
end
