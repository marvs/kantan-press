Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  namespace :admin do
    root to: "posts#index"

    resources :posts do
      member do
        patch :publish
        patch :unpublish
      end
    end

    resources :media_items, only: [ :index, :destroy ] do
      member { post :retry_fetch }
      collection do
        post :retry_all_failed
        post :upload
      end
    end

    resources :imports, only: [ :index, :new, :create, :show ]
    resources :comments, only: [ :index, :update, :destroy ]
  end

  get "up" => "rails/health#show", as: :rails_health_check

  # --- public site ----------------------------------------------------------
  root "posts#index"

  get "feed", to: "posts#feed", defaults: { format: :atom }, as: :feed
  get "category/:slug", to: "categories#show", as: :category
  get "tag/:slug", to: "tags#show", as: :tag

  # Monthly archives, matching WordPress's /YYYY/MM/ sidebar links.
  get "/:year/:month", to: "archives#show",
      constraints: { year: /\d{4}/, month: /\d{1,2}/ }, as: :archive

  # Catch-all for post and page slugs. Declared late so it can't shadow
  # anything above it, and constrained so it never swallows asset paths.
  get "/:slug", to: "posts#show", as: :post, constraints: { slug: %r{[^/.]+} }

  # Deeper legacy paths — WordPress date-based permalinks, attachment pages —
  # get one last chance to resolve through the redirect table.
  get "*path", to: "redirects#show", constraints: { path: %r{[^.]+} }
end
