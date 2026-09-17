FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "owner#{n}@example.com" }
    password { "password123" }
    name { "Chủ spa" }
  end
end
