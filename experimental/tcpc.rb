require 'socket'
require 'timeout'

TIMEOUT = 30

client = nil

begin
	timeout(TIMEOUT) do
		client = TCPSocket.open('localhost', 5555)
	end
	client.print 'hello'
	sleep 3.0
	client.puts 'end'
	client.puts ARGV.join(' ')
	client.flush
	answer = client.read
	puts answer
ensure
	client.close
	
end
