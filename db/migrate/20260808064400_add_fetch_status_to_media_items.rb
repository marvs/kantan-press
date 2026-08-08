class AddFetchStatusToMediaItems < ActiveRecord::Migration[8.1]
  def change
    # Media rows are created up front by the WordPress import and filled in
    # asynchronously by FetchMediaJob, so each one tracks its own progress.
    add_column :media_items, :status, :string, null: false, default: "pending"
    add_column :media_items, :fetch_error, :text
    add_column :media_items, :fetch_attempts, :integer, null: false, default: 0

    add_index :media_items, :status
  end
end
