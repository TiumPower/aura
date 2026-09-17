FactoryBot.define do
  factory :branch do
    workspace
    sequence(:name) { |n| "Cơ sở #{n}" }
    city { "TP.HCM" }
    status { "active" }
  end

  factory :room_type do
    workspace
    sequence(:key) { |n| "type_#{n}" }
    sequence(:name) { |n| "Loại phòng #{n}" }
  end

  factory :room do
    workspace
    branch
    sequence(:name) { |n| "Phòng #{n}" }
    capacity { 1 }
    status { "active" }
  end

  factory :staff_level do
    workspace
    sequence(:key) { |n| "level_#{n}" }
    sequence(:name) { |n| "Hạng #{n}" }
  end

  factory :staff_member do
    workspace
    branch
    sequence(:name) { |n| "KTV #{n}" }
    sequence(:code) { |n| format("%02d", n) }
    role { "therapist" }
    status { "active" }
  end

  factory :member_tier do
    workspace
    sequence(:key) { |n| "tier_#{n}" }
    sequence(:name) { |n| "Hạng thẻ #{n}" }
  end

  factory :member do
    workspace
    sequence(:name) { |n| "Khách #{n}" }
    sequence(:phone) { |n| "09#{format('%08d', n)}" }
    status { "active" }
  end

  factory :staff_shift do
    workspace
    staff_member
    branch
    work_date { Date.current }
    starts_at { Time.zone.now.change(hour: 9) }
    ends_at   { Time.zone.now.change(hour: 21) }
    kind { "shift" }
  end

  factory :expense do
    workspace
    category { "supplies" }
    amount { 500_000 }
    spent_on { Date.current }
  end
end

FactoryBot.define do
  factory :service_category do
    workspace
    sequence(:name) { |n| "Nhóm #{n}" }
  end

  factory :service do
    workspace
    sequence(:name) { |n| "Dịch vụ #{n}" }
    duration_minutes { 60 }
    price { 400_000 }
    active { true }
  end
end
