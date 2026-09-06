Rails.application.routes.draw do
  resource :session

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

    resources :themes, only: [ :index, :create, :edit, :update, :destroy ], param: :slug do
      member { post :activate }
    end

    resources :imports, only: [ :index, :new, :create, :show ]
    resources :comments, only: [ :index, :update, :destroy ]

    resource :settings, only: [ :show, :update ]

    # Its own resource rather than another settings field: a file upload needs
    # a multipart form of its own, and removal needs a verb the settings form
    # does not have.
    resource :favicon, only: [ :create, :destroy ]
  end

  get "up" => "rails/health#show", as: :rails_health_check

  # The PWA files Rails renders from app/views/pwa. Declared here for the same
  # reason as the theme assets below: without a route of their own, a browser
  # that already has a service worker registered for this origin re-fetches
  # /service-worker on every navigation, falls through to the catch-all and
  # raises RecordNotFound. The cost is that a post can no longer take either of
  # these two slugs.
  #
  # defaults: pins the format the way the feed route does. Without it the
  # extensionless path is negotiated as HTML and the .js/.json templates are
  # never found.
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker,
      defaults: { format: :js }
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest,
      defaults: { format: :json }

  # Theme assets. Declared before the public section because the catch-all
  # further down would otherwise swallow it. format: false keeps ".css" as part
  # of the path rather than letting Rails read it as a response format.
  get "themes/:slug/assets/*path", to: "theme_assets#show", as: :theme_asset,
      constraints: { slug: /[a-z0-9][a-z0-9\-]*/ }, format: false

  # Themes put screenshot.png at their root, as WordPress themes do, so it is
  # not reachable through the assets route above.
  get "themes/:slug/screenshot", to: "theme_assets#screenshot", as: :theme_screenshot,
      constraints: { slug: /[a-z0-9][a-z0-9\-]*/ }, format: false

  # --- public site ----------------------------------------------------------
  root "posts#index"

  get "feed", to: "posts#feed", defaults: { format: :atom }, as: :feed

  # Article search. Above the catch-all like everything else in this section;
  # the cost is that a post can no longer take the slug "search".
  resource :search, only: [ :show ]

  # An uploaded favicon, which lives under storage/ rather than public/ and so
  # needs a controller to reach it. Above the catch-all, at the same cost.
  get "favicon", to: "favicons#show", as: :favicon

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
