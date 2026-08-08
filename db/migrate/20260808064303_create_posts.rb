class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.string :title, null: false
      t.string :slug, null: false

      # WordPress block markup, stored verbatim. Block delimiters are HTML
      # comments, so this renders correctly in a browser as-is and round-trips
      # losslessly through the block editor.
      t.text :content
      t.text :excerpt

      t.string :status, null: false, default: "draft"
      t.string :post_type, null: false, default: "post"
      t.datetime :published_at

      t.references :author, foreign_key: { to_table: :users }
      t.references :featured_media_item, foreign_key: { to_table: :media_items }

      # Lets /?p=123 permalinks keep resolving after the migration.
      t.integer :wp_post_id

      t.timestamps
    end

    add_index :posts, :slug, unique: true
    add_index :posts, :wp_post_id, unique: true, where: "wp_post_id IS NOT NULL"
    add_index :posts, [ :status, :published_at ]
    add_index :posts, :published_at
  end
end
