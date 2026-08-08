# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_08_064400) do
  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "parent_id"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.integer "wp_term_id"
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
    t.index ["wp_term_id"], name: "index_categories_on_wp_term_id", unique: true, where: "wp_term_id IS NOT NULL"
  end

  create_table "comments", force: :cascade do |t|
    t.boolean "approved", default: true, null: false
    t.string "author_email"
    t.string "author_name"
    t.string "author_url"
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "parent_id"
    t.integer "post_id", null: false
    t.datetime "published_at"
    t.datetime "updated_at", null: false
    t.integer "wp_comment_id"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["post_id", "published_at"], name: "index_comments_on_post_id_and_published_at"
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["wp_comment_id"], name: "index_comments_on_wp_comment_id", unique: true, where: "wp_comment_id IS NOT NULL"
  end

  create_table "imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_log"
    t.string "filename", null: false
    t.datetime "finished_at"
    t.string "source_path", null: false
    t.datetime "started_at"
    t.json "stats", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_imports_on_status"
  end

  create_table "media_items", force: :cascade do |t|
    t.string "alt_text"
    t.bigint "byte_size"
    t.text "caption"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.integer "fetch_attempts", default: 0, null: false
    t.text "fetch_error"
    t.string "filename", null: false
    t.integer "height"
    t.string "key", null: false
    t.string "source_url"
    t.string "status", default: "pending", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.datetime "uploaded_at"
    t.integer "width"
    t.integer "wp_attachment_id"
    t.index ["key"], name: "index_media_items_on_key", unique: true
    t.index ["status"], name: "index_media_items_on_status"
    t.index ["wp_attachment_id"], name: "index_media_items_on_wp_attachment_id", unique: true, where: "wp_attachment_id IS NOT NULL"
  end

  create_table "post_categories", force: :cascade do |t|
    t.integer "category_id", null: false
    t.datetime "created_at", null: false
    t.integer "post_id", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_post_categories_on_category_id"
    t.index ["post_id", "category_id"], name: "index_post_categories_on_post_id_and_category_id", unique: true
    t.index ["post_id"], name: "index_post_categories_on_post_id"
  end

  create_table "post_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "post_id", null: false
    t.integer "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id", "tag_id"], name: "index_post_tags_on_post_id_and_tag_id", unique: true
    t.index ["post_id"], name: "index_post_tags_on_post_id"
    t.index ["tag_id"], name: "index_post_tags_on_tag_id"
  end

  create_table "posts", force: :cascade do |t|
    t.integer "author_id"
    t.text "content"
    t.datetime "created_at", null: false
    t.text "excerpt"
    t.integer "featured_media_item_id"
    t.string "post_type", default: "post", null: false
    t.datetime "published_at"
    t.string "slug", null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "wp_post_id"
    t.index ["author_id"], name: "index_posts_on_author_id"
    t.index ["featured_media_item_id"], name: "index_posts_on_featured_media_item_id"
    t.index ["published_at"], name: "index_posts_on_published_at"
    t.index ["slug"], name: "index_posts_on_slug", unique: true
    t.index ["status", "published_at"], name: "index_posts_on_status_and_published_at"
    t.index ["wp_post_id"], name: "index_posts_on_wp_post_id", unique: true, where: "wp_post_id IS NOT NULL"
  end

  create_table "redirects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "from_path", null: false
    t.integer "status", default: 301, null: false
    t.string "to_path", null: false
    t.datetime "updated_at", null: false
    t.index ["from_path"], name: "index_redirects_on_from_path", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.integer "wp_term_id"
    t.index ["slug"], name: "index_tags_on_slug", unique: true
    t.index ["wp_term_id"], name: "index_tags_on_wp_term_id", unique: true, where: "wp_term_id IS NOT NULL"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "posts"
  add_foreign_key "post_categories", "categories"
  add_foreign_key "post_categories", "posts"
  add_foreign_key "post_tags", "posts"
  add_foreign_key "post_tags", "tags"
  add_foreign_key "posts", "media_items", column: "featured_media_item_id"
  add_foreign_key "posts", "users", column: "author_id"
  add_foreign_key "sessions", "users"
end
