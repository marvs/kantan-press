class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.references :parent, foreign_key: { to_table: :categories }
      t.integer :wp_term_id

      t.timestamps
    end

    add_index :categories, :slug, unique: true
    add_index :categories, :wp_term_id, unique: true, where: "wp_term_id IS NOT NULL"
  end
end
