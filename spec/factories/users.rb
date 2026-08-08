FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "author#{n}@example.com" }
    password { "password-that-is-long-enough" }
  end
end
