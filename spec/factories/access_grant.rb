FactoryGirl.define do
  factory :access_grant do
    sequence(:resource_owner_id) { |n| n }
    application
    expires_in 100
  end
end
