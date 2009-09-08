require 'socket'
require 'filetrackerhub'
require 'mysql'
require 'thread'
require 'monitor'
require 'timeout'


# check whether gzip is there
gzipVersion = `gzip -V`
unless gzipVersion.index('gzip') == 0
	puts "Error: gzip is not installed."
	exit(1)
end

conn = nil

begin
	conn = openDatabaseConnection()
rescue Mysql::Error => e
	puts "Error: Unable to connect to database!"
	exit(1)
end

serverHost = 'localhost'
serverPort = 5555

serverHost = ARGV[0] if ARGV[0]
serverPort = ARGV[1].to_i if ARGV[1]

puts "Starting server at #{serverHost}:#{serverPort}..."
server = TCPServer.new(serverHost, serverPort);

# $databaseMutex = Mutex.new
# $fileMutex = Mutex.new
$fileMonitor = Monitor.new
$databaseMonitor = Monitor.new


def expectString(session, s)
	offset = 0
	s.each_byte do |b|
		c = session.getc
		return false if b != c
	end
	return true
end


while (newSession = server.accept)
	Thread.new(newSession) do |session|
		Timeout::timeout(30) do
			path = ''
			unless expectString(session, "PROTEOMATIC_FILETRACKER_REPORT\n")
				session.close
				Thread.exit
			end
			unless expectString(session, "VERSION 1\n")
				session.close
				Thread.exit
			end
			unless expectString(session, "LENGTH ")
				session.close
				Thread.exit
			end
			# read at most 7 digits (9999999 bytes max.)
			lengthString = ''
			7.times do
				b = session.getc
				c = b.chr()
				break unless (b >= ?0) && (b <= ?9)
				lengthString += c
			end
			length = lengthString.to_i

			yamlReport = session.read(length)
			
			#puts "Received new report:"
			#puts yamlReport
			
			session.puts "REPORT RECEIVED"
			
			# add report to database
			reportData = YAML::load(yamlReport)
			$databaseMonitor.synchronize do
				addReport(conn, reportData)
			end
			puts "Report committed at #{Time.now.to_s}."
			
			session.puts "REPORT COMMITTED"
			
			# archive report
			timestamp = Time.now.strftime("%Y-%m")
			currentArchiveFilename = "filetracker-reports-#{timestamp}.yaml"
			$fileMonitor.synchronize do
				File.open("archive/#{currentArchiveFilename}", "a") do |f|
					f.puts yamlReport
				end
				unarchivedFiles = Dir['archive/*.yaml']
				unarchivedFiles.each do |path|
					next if File::basename(path).include?(currentArchiveFilename)
					system("gzip \"#{path}\"")
				end
			end
=begin
		if input.strip == 'PROTEOMATIC_FILETRACKER_REPORT'
			input = session.gets
			if input.strip == 'VERSION 1'
				input = session.gets
				if input.index('LENGTH ') == 0
					length = input.strip.sub('LENGTH ', '').to_i
					
				end
			end
		end
=end
		end
		session.flush
		session.close
	end
end

conn.close
