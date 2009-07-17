require 'socket'
require 'filetrackerhub'
require 'mysql'
require 'thread'


=begin
info
parameters
submitJobBegin
submitJobChunk
submitJobEnd
queryTicket
getOutput
getOutputFile
deleteJob
=end

server = TCPServer.new('localhost',5555);

begin
conn = Mysql.new("localhost" , "testuser" , "user")
	conn.select_db("filetracker")
end

$databaseMutex = Mutex.new

while (session = server.accept)
        Thread.new(session) do |session|
        path = ''
 
  input = session.gets
  
  unless input.strip == 'PROTEOMATIC_FILETRACKER_REPORT'
    session.close
    return
  end
  puts input
  
  input = session.gets
  
  unless input.strip == 'VERSION 1'
    session.close
    return
  end
  puts input
  
  input = session.gets
  unless input.index('LENGTH ') == 0
    session.close
    return
  end
  
  length = input.strip.sub('LENGTH ', '').to_i
  puts "Reading #{length} bytes!"
  
  yamlReport = session.read(length)
  
  session.puts "REPORT RECEIVED"
  
  # add report to database
  $databaseMutex.synchronize do
    addReport(conn, YAML::load(yamlReport))
  end
  session.puts "REPORT COMMITTED"
  
  # archive report
  timestamp = Time.now.strftime("%Y-%m")
  File.open("archive/filetracker-reports-#{timestamp}.yaml", "a") do |f|
	f.puts yamlReport
  end

  session.flush
  session.close
  conn.close
  end
  end
