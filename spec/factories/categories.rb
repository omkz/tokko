FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    # slug is auto-generated from name

    trait :with_parent do
      association :parent, factory: :category
    end
  end
end
