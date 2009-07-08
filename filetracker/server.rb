require 'socket'
require 'mysql'
require 'filetrackerhub'
require 'yaml'

SERVER_HOST = '127.0.0.1'
SERVER_PORT = '4444'
DATABASE_URI = 'peaks.uni-muenster.de'
DATABASE_DATABASE = 'filetracker'
DATABASE_USER = 'testuser'
DATABASE_PASSWORD = 'user'

conn = Mysql.new(DATABASE_URI, DATABASE_USER, DATABASE_PASSWORD)
conn.select_db(DATABASE_DATABASE)

gs = TCPServer.open(SERVER_HOST, SERVER_PORT)
socks = [gs]
addr = gs.addr
addr.shift
printf("Server is on %s\n", addr.join(":"))

while true
	nsock = select(socks)
	next if nsock == nil
	for s in nsock[0]
		if s == gs
			socks.push(s.accept)
			print(s, " is accepted\n")
		else
			if s.eof?
				print(s, " is gone\n")
				s.close
				socks.delete(s)
			else
				str = s.gets
				s.write(str)
				s.flush
			end
		end
	end
end

conn.close

