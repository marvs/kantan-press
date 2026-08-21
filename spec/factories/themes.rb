FactoryBot.define do
  factory :theme do
    slug { "sample" }
    active { false }
    settings { {} }
  end
end
