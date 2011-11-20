FactoryGirl.define do
  factory :access_token do
    sequence(:resource_owner_id) { |n| n }
    application
    expires_at { DateTime.now + 10.days }
  end
end
