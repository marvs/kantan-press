class AddContentPlainToPosts < ActiveRecord::Migration[8.1]
  # The searchable form of the body. posts.content is Gutenberg block markup, so
  # searching it directly would match the markup rather than the writing — a
  # reader looking for "image" would hit every wp-block-image wrapper.
  #
  # Deliberately unindexed: SQLite cannot use an index for LIKE '%term%', so one
  # would cost every write and buy nothing.
  class MigrationPost < ActiveRecord::Base
    self.table_name = "posts"
  end

  def up
    add_column :posts, :content_plain, :text

    # Existing posts predate the model callback, so fill them here.
    # update_columns keeps callbacks and validations out of a data migration,
    # and the local model class keeps this migration working even if Post
    # changes later.
    MigrationPost.reset_column_information
    MigrationPost.find_each do |post|
      post.update_columns(content_plain: KantanPress::PlainText.call(post.content))
    end
  end

  def down
    remove_column :posts, :content_plain
  end
end
