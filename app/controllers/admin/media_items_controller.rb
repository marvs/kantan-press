module Admin
  class MediaItemsController < BaseController
    def index
      @media_items = MediaItem.recent
      @media_items = @media_items.where(status: params[:status]) if MediaItem.statuses.key?(params[:status])
      @counts = MediaItem.group(:status).count
    end

    # Called by the block editor's image block. Returns the shape Gutenberg's
    # media upload contract expects, so the block renders immediately.
    def upload
      media_item = MediaUploader.new.call(params[:file])

      render json: {
        id: media_item.id,
        url: media_item.url,
        link: media_item.url,
        alt: media_item.alt_text.to_s,
        caption: "",
        title: media_item.title.to_s,
        mime: media_item.content_type,
        type: media_item.content_type.to_s.split("/").first,
        subtype: media_item.content_type.to_s.split("/").last
      }, status: :created
    rescue MediaUploader::Error => e
      render json: { error: e.message }, status: :unprocessable_content
    rescue ObjectStore::UploadError => e
      render json: { error: e.message }, status: :bad_gateway
    end

    def destroy
      media_item = MediaItem.find(params[:id])
      ObjectStore.current.delete(media_item.key) if media_item.stored?
      media_item.destroy

      redirect_to admin_media_items_path, notice: "Media deleted."
    end

    def retry_fetch
      media_item = MediaItem.find(params[:id])
      media_item.update(status: :pending, fetch_error: nil)
      Wordpress::FetchMediaJob.perform_later(media_item.id)

      redirect_back fallback_location: admin_media_items_path, notice: "Re-queued #{media_item.filename}."
    end

    def retry_all_failed
      items = MediaItem.failed
      count = items.count
      items.find_each do |item|
        item.update(status: :pending, fetch_error: nil)
        Wordpress::FetchMediaJob.perform_later(item.id)
      end

      redirect_to admin_media_items_path, notice: "Re-queued #{count} image(s)."
    end
  end
end
