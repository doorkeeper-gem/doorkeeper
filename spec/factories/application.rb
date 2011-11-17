FactoryGirl.define do
  factory :application do
    sequence(:name){ |n| "Application #{n}" }
    redirect_uri "https://app.com/callback"
  end
end
