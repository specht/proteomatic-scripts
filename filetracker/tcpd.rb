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

		session.puts "ALRIGHT"
		
		session.flush
		session.close
	end
end
