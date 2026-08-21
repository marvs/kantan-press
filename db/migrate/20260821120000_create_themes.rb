class CreateThemes < ActiveRecord::Migration[8.1]
  def change
    create_table :themes do |t|
      t.string :slug, null: false
      t.boolean :active, null: false, default: false
      t.json :settings, null: false, default: {}

      t.timestamps
    end

    add_index :themes, :slug, unique: true

    # At most one theme is ever active. Enforced in the database as well as the
    # model: two active rows would leave the site's appearance depending on
    # which row came back first.
    add_index :themes, :active, unique: true, where: "active"
  end
end
