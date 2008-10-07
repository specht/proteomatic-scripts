require 'sqlite3'
require 'yaml'

=begin

BEGIN TRANSACTION;
CREATE TABLE files (
basename TEXT, directory TEXT, input_file BOOL, md5 TEXT, run_id NUMERIC, size NUMERIC);
CREATE TABLE runs (script_version TEXT, script_uri TEXT, host TEXT, user TEXT, end TIMESTAMP, start TIMESTAMP, id INTEGER PRIMARY KEY, parameters TEXT, script TEXT);
COMMIT;

Proteomatic output file tracking:
---------------------------------

path
ctime
filesize
md5
user
host
input files:
  path
  ctime
  size


=end

ls_DatabasePath = 'test.db'
lb_DatabaseExisted = File::exists?(ls_DatabasePath)
lk_Database = SQLite3::Database.new(ls_DatabasePath)
unless lb_DatabaseExisted
	puts 'Creating tables...'
	lk_Database.execute("create table `test` (a varchar2(30), b varchar2(30));") 
end

#lk_Database.execute("insert into `test` values('hello', 'fellow!')")
lk_Database.execute("insert into `runs` (`script`) values('Run OMSSA')")
li_Id = lk_Database.last_insert_row_id

lk_Rows = lk_Database.execute2("select * from `runs`")
puts lk_Rows.to_yaml
