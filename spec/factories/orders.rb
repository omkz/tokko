FactoryBot.define do
  factory :order do
    customer_name { Faker::Name.name }
    customer_email { Faker::Internet.email }
    customer_phone { Faker::PhoneNumber.phone_number }
    shipping_address { Faker::Address.full_address }
    total_price { 100_000 }
    status { :pending }

    trait :paid do
      status { :paid }
    end

    trait :cancelled do
      status { :cancelled }
    end
  end
end
