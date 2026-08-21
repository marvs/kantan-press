module Admin
  class SettingsController < BaseController
    # The allow-list. Anything not named here cannot be written from the form,
    # so a submitted "s3_secret_access_key" is dropped rather than stored.
    FIELDS = %w[site_title site_description posts_per_page].freeze

    def show
      @settings = SiteSetting.to_h
      @errors = {}
    end

    def update
      @settings = submitted
      @errors = validate(@settings)

      return render(:show, status: :unprocessable_content) if @errors.any?

      @settings.each { |key, value| SiteSetting.set(key, value) }
      redirect_to admin_settings_path, notice: "Settings saved."
    end

    private
      def submitted
        params.fetch(:settings, ActionController::Parameters.new).permit(*FIELDS).to_h
      end

      def validate(settings)
        errors = {}
        per_page = settings["posts_per_page"]

        if per_page.present? && !valid_per_page?(per_page)
          errors["posts_per_page"] = "must be a whole number between 1 and 50"
        end

        errors
      end

      def valid_per_page?(value)
        value.match?(/\A\d+\z/) && KantanPress::Config::POSTS_PER_PAGE_RANGE.cover?(value.to_i)
      end
  end
end
