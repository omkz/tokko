class FilterOption < ApplicationRecord
  belongs_to :filter_group
  has_many :product_filter_options, dependent: :destroy
  has_many :products, through: :product_filter_options

  validates :value, presence: true
  validates :slug, presence: true, uniqueness: { scope: :filter_group_id }

  before_validation :generate_slug, on: :create
  
  scope :ordered, -> { order(:position, :value) }

  private

  def generate_slug
    self.slug = value.parameterize if value.present? && slug.blank?
  end
end
