FactoryBot.define do
  factory :post do
    sequence(:title) { |n| "Post number #{n}" }
    content { "<!-- wp:paragraph -->\n<p>Body text.</p>\n<!-- /wp:paragraph -->" }
    status { :published }
    post_type { :post }
    published_at { 1.day.ago }

    trait :draft do
      status { :draft }
      published_at { nil }
    end

    trait :page do
      post_type { :page }
    end

    trait :scheduled do
      published_at { 1.week.from_now }
    end
  end

  factory :category do
    sequence(:name) { |n| "Category #{n}" }
  end

  factory :tag do
    sequence(:name) { |n| "Tag #{n}" }
  end

  factory :media_item do
    sequence(:key) { |n| "wp-content/uploads/2026/05/image-#{n}.png" }
    filename { File.basename(key) }
    content_type { "image/png" }
    source_url { "https://techandfi.com/#{key}" }

    trait :stored do
      status { :stored }
      byte_size { 1024 }
      uploaded_at { Time.current }
    end

    trait :failed do
      status { :failed }
      fetch_error { "404 Not Found" }
    end
  end

  factory :comment do
    post
    author_name { "Reader" }
    content { "Nice post." }
    published_at { 1.hour.ago }
    approved { true }
  end
end
