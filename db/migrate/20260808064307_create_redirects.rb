class CreateRedirects < ActiveRecord::Migration[8.1]
  def change
    create_table :redirects do |t|
      t.string :from_path, null: false
      t.string :to_path, null: false
      t.integer :status, null: false, default: 301

      t.timestamps
    end

    add_index :redirects, :from_path, unique: true
  end
end
