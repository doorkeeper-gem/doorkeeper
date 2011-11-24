FactoryGirl.define do
  factory :access_grant do
    sequence(:resource_owner_id) { |n| n }
    application
    redirect_uri "https://app.com/callback"
    expires_in 100
  end
end
