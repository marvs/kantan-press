class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :wp_term_id

      t.timestamps
    end

    add_index :tags, :slug, unique: true
    add_index :tags, :wp_term_id, unique: true, where: "wp_term_id IS NOT NULL"
  end
end
