class CreateProteomaticFiles < ActiveRecord::Migration
  def self.up
    create_table :proteomatic_files do |t|
      t.string :basename
      t.string :directory
      t.boolean :input_file
      t.string :md5
      t.integer :run_id
      t.integer :size

      t.timestamps
    end
  end

  def self.down
    drop_table :proteomatic_files
  end
end
