class CreateMediaItems < ActiveRecord::Migration[8.1]
  def change
    create_table :media_items do |t|
      # Object key in the bucket. WordPress uploads keep their original
      # "wp-content/uploads/YYYY/MM/name.ext" path so that a single host
      # substitution fixes every <img src> and srcset entry in imported posts.
      t.string :key, null: false
      t.string :filename, null: false
      t.string :content_type
      t.bigint :byte_size
      t.integer :width
      t.integer :height
      t.string :alt_text
      t.string :title
      t.text :caption

      # Provenance, so a re-run can skip what it already fetched.
      t.integer :wp_attachment_id
      t.string :source_url
      t.datetime :uploaded_at

      t.timestamps
    end

    add_index :media_items, :key, unique: true
    add_index :media_items, :wp_attachment_id, unique: true, where: "wp_attachment_id IS NOT NULL"
  end
end
