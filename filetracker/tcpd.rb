require 'socket'
require 'filetrackerhub'


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
  
  puts yamlReport
  addReport(conn, YAML::load(yamlReport))

  session.puts "REPORT RECEIVED"
  

  session.puts "ALRIGHT"
                
  session.flush
  session.close
  end
  end
