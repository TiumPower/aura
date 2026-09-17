FactoryBot.define do
  factory :workspace do
    sequence(:name) { |n| "Spa #{n}" }
    sequence(:subdomain) { |n| "ws#{n}" }
    status { "active" }
    plan { "business" }
    paid_until { 1.year.from_now }
  end
end
