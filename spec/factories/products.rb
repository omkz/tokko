FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Product #{n}" }
    description { "A test product description." }
    status { "active" }
    # after_create callback creates a default ProductVariant automatically

    trait :with_category do
      association :category
    end

    trait :with_collection do
      after(:create) do |product|
        collection = create(:collection)
        product.collections << collection
      end
    end
  end
end
