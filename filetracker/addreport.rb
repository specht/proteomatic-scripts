require 'yaml'
require 'mysql'

def addReport(report)
  report['run']['parameters'].each do |parameter|
    key = parameter.keys.first
    value = parameter.values.first
    puts "#{key}: #{value}"
  end
  report['files'].each do |file|
    unless file['basename']
      puts "Error: Obsolete report format."
      exit 1
    end
    
    identifier = "basename#{file['basename']}"
    identifier = "md5#{file['md5']}" if file['md5']
    puts identifier
  end
  

  puts "-----------------------"
  print report['run']["user"].strip, "-", report['run']["script_title"].strip, "-", report['run']["host"].strip, "-", report['run']["uri"].strip, "-", 
  report['run']["version"].strip, "-", report['run']["start_time"].strip, "-", report['run']["end_time"].strip "\n"

  puts "-----------------------"
  puts

  user = report['run']["user"].strip
  title = report ['run']["script_title"].strip
  host = report['run']["host"].strip
  uri = report['run']["uri"].strip
  version = report['run']["version"].strip
  start_time = report['run']["start_time"].strip
  end_time = report['run']["end_time"].strip

  conn.query( 
    "INSERT INTO `runs` (user, title, host, uri, version, start_time, end_time ) 
    VALUES ( '#{user}', '#{title}', '#{host}', '#{uri}', '#{version}', '#{start_time}', '#{end_time}' )")
  end

  conn.query( 
    "INSERT INTO parameters(key, value, run_id ) 
    VALUES (#{key}, #{value}, #{run_id})")
  end
end

conn = Mysql.new("localhost" , "root" , "testen")
conn.select_db("yaml")

ARGV.each do |path|
  puts path
  report = YAML::load_file(path)
  addReport(report)
end

conn.close
