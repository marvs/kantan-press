module Admin
  class ThemesController < BaseController
    before_action :load_bundle, only: %i[activate edit update destroy]

    def index
      load_themes
    end

    def create
      upload = params[:file]
      return redirect_to(admin_themes_path, alert: "Choose a theme .zip first.") if upload.blank?

      result = Themes::Installer.call(upload, overwrite: params[:overwrite] == "1")
      return redirect_to(admin_themes_path, notice: "Installed #{result.bundle.name}.") if result.success?

      load_themes
      @install_errors = result.errors
      render :index, status: :unprocessable_content
    end

    def activate
      Theme.find_or_initialize_by(slug: @bundle.slug).activate!

      redirect_to admin_themes_path, notice: "#{@bundle.name} is now the active theme."
    end

    def edit
      @theme = theme_record
    end

    def update
      @theme = theme_record

      if params[:reset].present?
        @theme.reset_settings!
        return redirect_to(edit_admin_theme_path(@bundle.slug), notice: "Settings reset to the theme's defaults.")
      end

      @theme.assign_settings(setting_values, submitted_keys: submitted_setting_keys)
      return redirect_to(edit_admin_theme_path(@bundle.slug), notice: "Settings saved.") if @theme.save

      render :edit, status: :unprocessable_content
    end

    def destroy
      result = Themes::Uninstaller.call(@bundle.slug)

      if result.success?
        redirect_to admin_themes_path, notice: "Uninstalled #{@bundle.name}."
      else
        redirect_to admin_themes_path, alert: result.errors.to_sentence
      end
    end

    private
      def load_themes
        @bundles = Themes::Registry.all
        @selection = Theme.selection
      end

      def load_bundle
        @bundle = Themes::Registry.find(params[:slug])

        redirect_to admin_themes_path, alert: "That theme is not installed." if @bundle.nil?
      end

      # A theme row only exists once someone activates it or changes a setting,
      # so the default theme has none until it is touched.
      def theme_record
        Theme.find_or_initialize_by(slug: @bundle.slug)
      end

      def schema_keys = @bundle.settings_schema.map(&:key)

      # Only keys the theme declared are permitted through; the rest are passed
      # to the model as names so it can say which ones it rejected rather than
      # dropping them silently.
      def setting_values
        submitted_settings.permit(*schema_keys).to_h
      end

      def submitted_setting_keys
        submitted_settings.keys.map(&:to_s)
      end

      def submitted_settings
        params.fetch(:settings, ActionController::Parameters.new)
      end
  end
end
