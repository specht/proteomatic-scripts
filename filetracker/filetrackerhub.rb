def q(s)
	return s.gsub(/[']/, '\\\\\'') if s.class == String
	return s
end

def addReport(conn, report)
	if report['files'] && report['files'].class == Array && report['files'].size > 0
		unless report['files'].first['basename']
			puts "Skipping report... obsolete format."
			return
		end
	end
	#runs
# 	puts "-----------------------"
# 	print report['run']["user"].strip, "-", report['run']["script_title"].strip, "-", report['run']["host"].strip, "-", report['run']["script_uri"].strip, "-", report['run']["version"].strip, "-", report['run']["start_time"], "-", report['run']["end_time"], "\n"
# 	puts "-----------------------"
# 	puts

	user = report['run']["user"].strip
	title = report ['run']["script_title"].strip
	host = report['run']["host"].strip
	script_uri = report['run']["script_uri"].strip
	version = report['run']["version"].strip
	start_time = report['run']["start_time"]
	end_time = report['run']["end_time"]

	timeFmtStr= "%Y-%m-%d %H:%M:%S"
	startTimeFormatted = start_time.strftime(timeFmtStr)
	endTimeFormatted = end_time.strftime(timeFmtStr)

	conn.query( "INSERT INTO `runs` (user, title, host, script_uri, version, start_time, end_time ) VALUES ( '#{user}', '#{title}', '#{host}', '#{script_uri}', '#{version}', '#{startTimeFormatted}', '#{endTimeFormatted}')")
	if conn.affected_rows != 1
		puts "Could not be added!"
	end
	run_id = conn.insert_id()


	if report['run']['parameters'] 
		report['run']['parameters'].each do |parameter|
			code_key = parameter.keys.first.strip
			code_value = parameter.values.first
			code_value.strip! if code_value.class == String
			conn.query( "INSERT INTO parameters(run_id, code_key, code_value ) VALUES ( '#{run_id}', '#{code_key}', '#{q(code_value)}')")
			if conn.affected_rows != 1
				puts "Could not be added!"
			end
		end
	end


	if report['files']
		#files
		report['files'].each do |file|

		identifier = "basename#{file['basename']}"
		identifier = "md5#{file['md5']}" if file['md5']
# 		puts identifier
		size = file['size'].to_i
		basename = file['basename']
		directory = file['directory']
		ctime = file['ctime'].strftime(timeFmtStr)
		mtime = file['mtime'].strftime(timeFmtStr)

		result = conn.query( "SELECT filecontent_id FROM filecontents WHERE identifier='#{identifier}' and size = '#{size}'")

		filecontent_id = nil

		if result.num_rows == 0
			conn.query("INSERT INTO `filecontents`(identifier, size) VALUES ('#{identifier}', '#{size}')")
			if conn.affected_rows != 1
				puts "Could not be added!"
			end
			filecontent_id = conn.insert_id()
		else
			filecontent_id = result.fetch_row()[0]
		end

		s = "SELECT filewithname_id FROM filewithname WHERE filecontent_id='#{filecontent_id}' AND code_basename='#{q(basename)}' AND directory='#{q(directory)}' AND ctime='#{ctime}' and mtime='#{mtime}'"
# 		puts s
		result = conn.query(s)
# 		puts result

		filewithname_id = nil

		if result.num_rows == 0
			conn.query("INSERT INTO `filewithname` (filecontent_id, code_basename, directory, ctime, mtime) VALUES ('#{filecontent_id}', '#{q(basename)}', '#{q(directory)}', '#{ctime}', '#{mtime}')")
			if conn.affected_rows != 1
				puts "Could not be added!"
			end
			filewithname_id = conn.insert_id()
		else
			filewithname_id = result.fetch_row()[0]
		end

		input_file = file['input_file']
		s = "INSERT INTO run_filewithname (`run_id`, `filewithname_id`, `input_file`) VALUES('#{run_id}', '#{filewithname_id}', '#{input_file ? '1' : '0'}')"
# 		puts s
		conn.query(s)
		end
	end
end
