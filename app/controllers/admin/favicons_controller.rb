module Admin
  class FaviconsController < BaseController
    def create
      result = Branding::FaviconUploader.call(params[:favicon])

      return redirect_to(admin_settings_path, alert: result.errors.first) unless result.success?

      redirect_to admin_settings_path, notice: "Favicon updated."
    end

    def destroy
      Branding::Favicon.remove

      redirect_to admin_settings_path, notice: "Favicon removed. The Kantan Press mark is back."
    end
  end
end
