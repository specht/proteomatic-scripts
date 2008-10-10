class CreateRuns < ActiveRecord::Migration
  def self.up
    create_table :runs do |t|
      t.string :script_version
      t.string :script_uri
      t.string :host
      t.string :user
      t.timestamp :start_time
      t.timestamp :end_time
      t.text :parameters
      t.string :script_title

      t.timestamps
    end
  end

  def self.down
    drop_table :runs
  end
end
