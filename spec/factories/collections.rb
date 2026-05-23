FactoryBot.define do
  factory :collection do
    sequence(:name) { |n| "Collection #{n}" }
    active { true }
    # slug is auto-generated from name
  end
end
