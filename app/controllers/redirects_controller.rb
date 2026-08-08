# Catch-all for paths the rest of the routes didn't claim. Old permalinks
# recorded during the WordPress import are resolved here; anything else 404s.
class RedirectsController < ApplicationController
  allow_unauthenticated_access

  def show
    redirect = Redirect.lookup("/#{params[:path]}")
    raise ActiveRecord::RecordNotFound unless redirect

    redirect_to redirect.to_path, status: redirect.status
  end
end
