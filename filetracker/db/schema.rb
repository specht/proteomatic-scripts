# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20081007114813) do

  create_table "proteomatic_files", :force => true do |t|
    t.string   "basename"
    t.string   "directory"
    t.boolean  "input_file"
    t.string   "md5"
    t.integer  "run_id"
    t.integer  "size"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "runs", :force => true do |t|
    t.string   "script_version"
    t.string   "script_uri"
    t.string   "host"
    t.string   "user"
    t.datetime "start_time"
    t.datetime "end_time"
    t.text     "parameters"
    t.string   "script_title"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
