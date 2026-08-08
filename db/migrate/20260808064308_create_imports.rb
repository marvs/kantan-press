class CreateImports < ActiveRecord::Migration[8.1]
  def change
    create_table :imports do |t|
      t.string :filename, null: false
      t.string :source_path, null: false
      t.string :status, null: false, default: "pending"

      # Per-record tallies: posts/pages/media/categories/tags/comments created,
      # skipped, and failed. Shown on the admin import page.
      t.json :stats, null: false, default: {}
      t.text :error_log

      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :imports, :status
  end
end
