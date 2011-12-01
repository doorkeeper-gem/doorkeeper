FactoryGirl.define do
  factory :access_token do
    sequence(:resource_owner_id) { |n| n }
    application
    expires_in { Time.now + 2.hours }
  end
end
