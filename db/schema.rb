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

ActiveRecord::Schema[8.1].define(version: 2026_07_09_093519) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "processing_jobs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.json "result"
    t.string "status"
    t.datetime "updated_at", null: false
    t.bigint "user_file_id", null: false
    t.index ["user_file_id"], name: "index_processing_jobs_on_user_file_id"
  end

  create_table "share_links", force: :cascade do |t|
    t.integer "access_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.integer "max_accesses"
    t.string "passcode_digest"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_file_id", null: false
    t.index ["token"], name: "index_share_links_on_token", unique: true
    t.index ["user_file_id"], name: "index_share_links_on_user_file_id"
  end

  create_table "user_files", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "file_size"
    t.string "file_type"
    t.string "name"
    t.datetime "processed_at"
    t.string "s3_key"
    t.string "status"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_user_files_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "password_digest"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "processing_jobs", "user_files"
  add_foreign_key "share_links", "user_files"
  add_foreign_key "user_files", "users"
end
