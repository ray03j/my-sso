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

ActiveRecord::Schema[7.1].define(version: 4) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "access_tokens", force: :cascade do |t|
    t.string "token", null: false
    t.string "user_id", null: false
    t.string "client_id", null: false
    t.string "scope"
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_access_tokens_on_token", unique: true
    t.index ["user_id", "client_id"], name: "index_access_tokens_on_user_id_and_client_id"
  end

  create_table "authorization_codes", force: :cascade do |t|
    t.string "code", null: false
    t.string "user_id", null: false
    t.string "client_id", null: false
    t.string "redirect_uri"
    t.string "scope"
    t.datetime "expires_at", null: false
    t.boolean "used", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "used"], name: "index_authorization_codes_on_client_id_and_used"
    t.index ["code"], name: "index_authorization_codes_on_code", unique: true
  end

  create_table "consents", force: :cascade do |t|
    t.string "user_id", null: false
    t.string "client_id", null: false
    t.string "scope", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "client_id"], name: "index_consents_on_user_id_and_client_id", unique: true
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.string "token", null: false
    t.string "user_id", null: false
    t.string "client_id", null: false
    t.string "scope"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_refresh_tokens_on_token", unique: true
    t.index ["user_id", "client_id"], name: "index_refresh_tokens_on_user_id_and_client_id"
  end

end
