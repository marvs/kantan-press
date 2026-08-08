module Admin
  # Everything under /admin requires a signed-in user. The public site
  # controllers opt out of authentication individually.
  class BaseController < ApplicationController
    layout "admin"

    private
      def page_params = params.permit(:page, :q, :status).to_h.symbolize_keys
  end
end
