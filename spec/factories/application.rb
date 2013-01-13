FactoryGirl.define do
  factory :application, :class => Doorkeeper.client do
    sequence(:name){ |n| "Application #{n}" }
    redirect_uri "https://app.com/callback"
  end
end
