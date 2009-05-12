require 'socket'

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

server = TCPServer.new('', 5555);

while (session = server.accept)
	Thread.new(session) do |session|
		path = ''
		while !session.eof?
			print 'r'
			t = session.gets
			path += t
			
			puts ": #{t}"
		end
		puts 'eof!'
		puts path

		session.puts "The people ask, the people get: #{path}"
		if (path.index('wait') == 0)
			puts 'sleeping'
			STDOUT.flush
			sleep 10.0 
			puts 'waking up'
			STDOUT.flush
		end
		session.close
	end
end
