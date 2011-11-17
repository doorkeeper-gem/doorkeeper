FactoryGirl.define do
  factory :application do
    sequence(:name){ |n| "Application #{n}" }
  end
end
