module Admin
  class CommentsController < BaseController
    def index
      @comments = Comment.includes(:post).order(published_at: :desc)
      @comments = @comments.where(approved: params[:approved] == "true") if params[:approved].present?
      @counts = Comment.group(:approved).count
    end

    def update
      comment = Comment.find(params[:id])
      comment.update(approved: params[:approved] == "true")

      redirect_back fallback_location: admin_comments_path, notice: "Comment updated."
    end

    def destroy
      Comment.find(params[:id]).destroy

      redirect_to admin_comments_path, notice: "Comment deleted."
    end
  end
end
