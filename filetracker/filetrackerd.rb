require 'socket'
require 'filetrackerhub'
require 'mysql'
require 'thread'


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

$databaseMutex = Mutex.new
$fileMutex = Mutex.new

while (session = server.accept)
	Thread.new(session) do |session|
		path = ''
		
		input = session.gets
		
		unless input.strip == 'PROTEOMATIC_FILETRACKER_REPORT'
			session.close
			return
		end
		
		input = session.gets
		
		unless input.strip == 'VERSION 1'
			session.close
			return
		end
		
		input = session.gets
		unless input.index('LENGTH ') == 0
			session.close
			return
		end
		
		length = input.strip.sub('LENGTH ', '').to_i
		
		yamlReport = session.read(length)
		
		puts "Received new report:"
		puts yamlReport
		
		session.puts "REPORT RECEIVED"
		
		# add report to database
		reportData = YAML::load(yamlReport)
		$databaseMutex.synchronize do
			addReport(conn, reportData)
		end
		puts "Report committed."
		puts
		
		session.puts "REPORT COMMITTED"
		
		# archive report
		timestamp = Time.now.strftime("%Y-%m")
		currentArchiveFilename = "filetracker-reports-#{timestamp}.yaml"
		$fileMutex.synchronize do
			File.open("archive/#{currentArchiveFilename}", "a") do |f|
				f.puts yamlReport
			end
			unarchivedFiles = Dir['archive/*.yaml']
			unarchivedFiles.each do |path|
				next if File::basename(path).include?(currentArchiveFilename)
				system("gzip \"#{path}\"")
			end
		end
		session.flush
		session.close
	end
end

conn.close
