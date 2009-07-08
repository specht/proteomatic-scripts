require 'mysql'
require 'yaml'
require 'filetrackerhub'


#Datenbankverbindung  
begin
	conn = Mysql.new("localhost" , "testuser" , "user")
	conn.select_db("filetracker")

	ARGV.each do |path|
		puts path
		report = YAML::load_file(path)
		addReport(conn, report)
	end
rescue Mysql::Error => e
     puts "Error code: #{e.errno}"
     puts "Error message: #{e.error}"
     puts "Error SQLSTATE: #{e.sqlstate}"
	 exit 1
ensure
	conn.close
end
