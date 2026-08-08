module Sluggable
  extend ActiveSupport::Concern

  included do
    before_validation :generate_slug, if: -> { slug.blank? }
    validates :slug, presence: true, uniqueness: true,
                     format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
                               message: "must be lowercase words separated by hyphens" }
  end

  # Deliberately no to_param override. Public routes take the slug explicitly
  # (post_path(post.slug)), so overriding it here would only break the admin,
  # whose RESTful paths need the primary key.

  private
    # WordPress slugs arrive already-formed and are kept verbatim so permalinks
    # survive the migration. This only fills in a slug for records created here.
    def generate_slug
      base = slug_source.to_s.parameterize
      return if base.blank?

      candidate = base
      suffix = 1
      while self.class.where(slug: candidate).where.not(id: id).exists?
        suffix += 1
        candidate = "#{base}-#{suffix}"
      end
      self.slug = candidate
    end

    def slug_source
      respond_to?(:title) ? title : name
    end
end
