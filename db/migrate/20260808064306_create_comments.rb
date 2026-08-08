class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :post, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :comments }

      t.string :author_name
      t.string :author_email
      t.string :author_url
      t.text :content

      t.boolean :approved, null: false, default: true
      t.datetime :published_at

      t.integer :wp_comment_id

      t.timestamps
    end

    add_index :comments, :wp_comment_id, unique: true, where: "wp_comment_id IS NOT NULL"
    add_index :comments, [ :post_id, :published_at ]
  end
end
