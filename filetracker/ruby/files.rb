require 'yaml'
require 'mysql'
require 'FilewithnameDao'
require 'RunFilecontents'
require 'Filecontents'

object = YAML::load_file('c:\users\zimbo\desktop\praktikum\filetracker\test.yaml')

my = Mysql.new("localhost" , "root" , "testen")
my.autocomit(false);

#Insert rows
item = Filewithname.new();
item.filewithname_id = value;
item.filecontent_id = value;
item.basename = value;
item.directory = value;
item.ctime = value;
item.mtime = value;
itemDao = FilewithnameDao.new(my);
item.Dao.insert(item);
end

#Insert rows
head = Runfilecontents.new();
head.run_id = value;
head.filecontent_id = value;
head.input_file =value;
headDao = RunFilecontentsDao.new(my);
head.Dao.insert(head);
end

#Insert rows
piece = Filecontents.new();
piece.filecontent_id = value;
piece.identifier = value;
piece.size = value;
pieceDao = Filecontents.new(my);
piece.Dao.insert(piece);
end







  


  







