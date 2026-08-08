module Admin
  class ImportsController < BaseController
    UPLOAD_DIR = Rails.root.join("storage", "imports")

    def index
      @imports = Import.recent
    end

    def new
      @import = Import.new
    end

    def create
      upload = params[:file]
      return redirect_to(new_admin_import_path, alert: "Choose a WXR export file first.") if upload.blank?

      import = Import.create!(
        filename: upload.original_filename,
        source_path: store_upload(upload),
        status: :pending
      )
      Wordpress::ImportJob.perform_later(import.id)

      redirect_to admin_import_path(import), notice: "Import queued."
    end

    def show
      @import = Import.find(params[:id])
      @media_counts = MediaItem.group(:status).count
    end

    private
      # The uploaded XML is kept on disk because the import job reads it after
      # the request has finished, and re-running an import needs the original.
      def store_upload(upload)
        UPLOAD_DIR.mkpath
        destination = UPLOAD_DIR.join("#{Time.current.to_i}-#{sanitize(upload.original_filename)}")

        File.open(destination, "wb") { |file| IO.copy_stream(upload.tempfile, file) }
        destination.to_s
      end

      def sanitize(filename)
        File.basename(filename.to_s).gsub(/[^a-zA-Z0-9._-]/, "_")
      end
  end
end
