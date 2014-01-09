FactoryGirl.define do
  factory :application, :class => Doorkeeper::Application do
    sequence(:name){ |n| "Application #{n}" }
    redirect_uris "https://app.com/callback"
  end
end
