require 'yaml'
require 'mysql'

object = YAML::load_file('c:\users\zimbo\desktop\praktikum\filetracker\test.yaml')

conn = Mysql.new("localhost" , "root" , "testen","yaml")


conn.query( 
  "INSERT INTO filewithname ( filewithname_id, filecontent_id, basename, directory, ctime, mtime ) 
  VALUES ( ?, ?, ?, ?, ?, ? )")
end

conn.query(
  "INSERT INTO filecontents ( filecontent_id, identifier ) 
  VALUES ( ?, ? )")
end

conn.query(
  "INSERT INTO run_filecontents ( run_id, filecontent_id, input_file ) 
  VALUES ( ?, ?, ? )")
end

conn.query(
  "INSERT INTO  md5table ( md5_id, size, md5 ) 
  VALUES ( ?, ?, ? )"
end

conn.query(
  "INSERT INTO basenametable ( basename_id, size, basename ) 
  VALUES ( ?, ?, ? )"
end

conn.close


  


  







