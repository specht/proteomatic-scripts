# Copyright (c) 2007-2008 Michael Specht
# 
# This file is part of Proteomatic.
# 
# Proteomatic is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# Proteomatic is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Proteomatic.  If not, see <http://www.gnu.org/licenses/>.

require 'include/misc'
require 'webrick'
require 'drb'
require 'yaml'
require 'stringio'
require 'zlib'


def handleArguments(ak_Script, ak_Arguments)
	$gb_Gui = false
	if ak_Arguments.first == '---gui'
		ak_Arguments.slice!(0)
		$gb_Gui = true
	end
	
	if ak_Arguments == ['--help']
		puts ak_Script.help()
		return
	elsif ak_Arguments == ['---info']
		puts ak_Script.info()
		return
	elsif ak_Arguments == ['---getParameters']
		puts ak_Script.getParameters()
		return
	elsif ak_Arguments == ['---getInfoAndParameters']
		puts ak_Script.infoAndParameters()
		return
	elsif ak_Arguments.first == '--query'
		ak_Arguments.slice!(0)
		if ak_Arguments.empty?
			puts 'Error: No ticket was specified after --query.'
			return
		end
		ls_Ticket = ak_Arguments.first
		if $gb_Gui
			puts '---queryTicket'
			lk_State = ak_Script.queryTicket(ls_Ticket)
			puts lk_State['state']
			puts lk_State['infront'] if lk_State['state'] == 'waiting'
			if (lk_State['state'] == 'finished')
				puts lk_State['output']['directory']
				puts lk_State['output']['prefix']
				lk_State['output']['files'].each { |x| puts x }
			end
		else
			puts ak_Script.queryTicket(ls_Ticket).to_yaml
		end
		return
	elsif ak_Arguments.first == '--getStandardOutput'
		ak_Arguments.slice!(0)
		if ak_Arguments.empty?
			puts 'Error: No ticket was specified after --getStandardOutput.'
			return
		end
		ls_Ticket = ak_Arguments.first
		lk_State = ak_Script.queryTicket(ls_Ticket)
		if (lk_State['state'] == 'finished')
			puts ak_Script.getStandardOutput(ls_Ticket)
		else
			puts 'Error: Job has not finished yet.'
		end
		return
	elsif ak_Arguments.first == '--getOutputFiles'
		ak_Arguments.slice!(0)
		if ak_Arguments.empty?
			puts 'Error: No ticket was specified after --getOutputFiles.'
			return
		end
		ls_Ticket = ak_Arguments.first
		lk_State = ak_Script.queryTicket(ls_Ticket)
		if (lk_State['state'] == 'finished')
			ls_OutputDirectory = lk_State['output']['directory']
			ls_Prefix = lk_State['output']['prefix']
			lk_Files = lk_State['output']['files']
			
			if ak_Arguments.include?('--outputDirectory')
				ls_OutputDirectory = ak_Arguments[ak_Arguments.index('--outputDirectory') + 1]
				ak_Arguments.slice!(ak_Arguments.index('--outputDirectory'), 2)
			end
			if ak_Arguments.include?('--outputPrefix')
				ls_Prefix = ak_Arguments[ak_Arguments.index('--outputPrefix') + 1]
				ak_Arguments.slice!(ak_Arguments.index('--outputPrefix'), 2)
			end
			lk_Errors = Array.new
			lk_Errors.push("No output directory was specified.") if ls_OutputDirectory.empty?
			lk_Errors.push("The output directory '#{ls_OutputDirectory}' does not exist.") unless File::directory?(ls_OutputDirectory)
			lk_Files.each do |ls_Filename|
				ls_NewFilename = ls_Filename
				ls_NewFilename = File::join(ls_OutputDirectory, ls_Prefix + ls_NewFilename)
				lk_Errors.push("#{ls_NewFilename} already exists.") if File::exists?(ls_NewFilename)
			end
			
			if lk_Errors.empty?
				puts 'Downloading output files...'
				lk_Files.each do |ls_Filename|
					ls_NewFilename = ls_Filename
					ls_NewFilename = File::join(ls_OutputDirectory, ls_Prefix + ls_NewFilename)
					puts "Writing #{ls_NewFilename}..."
					File.open(ls_NewFilename, 'w') do |lk_File|
						lk_File.write(ak_Script.getOutputFile(ls_Ticket, ls_Filename))
					end
				end
				puts 'All output files have been successfully downloaded.'
			else
				puts "Error#{lk_Errors.size == 1 ? '' : 's'}:"
				puts lk_Errors.join("\n");
			end
			
		else
			puts 'Error: Job has not finished yet.'
		end
		return
	end
	
	lk_Files = Hash.new
	lk_Directories = Array.new
	
	ak_Arguments.collect! do |ls_Argument|
		ls_Result = ls_Argument
		if File::file?(ls_Argument)
			#lk_Files[ls_Argument] = File::read(ls_Argument) 
			lk_Files[ls_Argument] = nil
			ls_Result = '----ignore----' + ls_Result
		elsif File::directory?(ls_Argument)
			lk_Directories.push(ls_Argument) 
			ls_Result = '----ignore----' + ls_Result
		elsif ls_Argument == '-[output]directory'
			ls_Result = '----ignore----' + ls_Result
		end
		ls_Result
	end
	
	ls_Ticket = ak_Script.submit(ak_Arguments, lk_Files, lk_Directories.first)
	if ($gb_Gui)
		puts "command=submitJob"
	end	
	li_TotalSize = 0
	lk_Files.each_key { |ls_Path| li_TotalSize += File::size(ls_Path) }
	li_SubmittedSize = 0
	STDOUT.puts "[---proteomaticProgress]start/#{li_TotalSize}"
	STDOUT.flush
	lk_Files.each_key do |ls_Path|
		File::open(ls_Path, 'rb') do |lk_File|
			while (!lk_File.eof?)
				ls_Chunk = lk_File.read(16384)
				li_SubmittedSize += ls_Chunk.size
				ak_Script.submitInputFileChunk(ls_Ticket, ls_Path,  Zlib::Deflate.deflate(ls_Chunk, Zlib::BEST_SPEED))
				STDOUT.puts "[---proteomaticProgress]#{li_SubmittedSize}/#{li_TotalSize}"
				STDOUT.flush
			end
		end
	end
	ak_Script.submitInputFilesFinished(ls_Ticket)
	STDOUT.puts "[---proteomaticProgress]finished"
	STDOUT.flush
	
	if ($gb_Gui)
		puts "ticket=#{ls_Ticket}"
	else
		puts "Your ticket is #{ls_Ticket}."
		
		puts wordwrap("Now waiting for your job to finish. If you do not wish to wait, \
 you can abort this script now and retrieve your results later with your ticket. \
 From the command line: \n\nruby remote.rb #{$gs_Uri} --wait #{ls_Ticket}\n\n")
		
		lf_WaitTime = 1.0
		lb_Finished = false
		lb_Running = false
		while !lb_Finished
			sleep lf_WaitTime
			lf_WaitTime += 1.0 if lf_WaitTime < 10.0
			lf_WaitTime += 2.0 if lf_WaitTime < 20.0
			lk_State = ak_Script.queryTicket(ls_Ticket)
			lb_Finished = lk_State['state'] == 'finished'
			if !lb_Running && lk_State['state'] == 'running'
				puts "Your job is currently being processed."
				lb_Running = true
			end
		end
		
		puts "Your job has finished."
		
=begin		
		lk_OutputFiles = ak_Script.outputFiles(ls_Ticket)
		
		unless lk_OutputFiles.empty?
			ls_OutputDirectory = ak_Script.outputDirectoryAccordingToInputFiles(ls_Ticket)
			
			unless ls_OutputDirectory
				puts "Unable to determine output directory."
				return
			end
			
			lk_Errors = Array.new
			lk_OutputFiles.each do |ls_Filename|
				ls_Path = File::join(ls_OutputDirectory, ls_Filename)
				lk_Errors.push("#{ls_Path} already exists. I won't overwrite this file.") if File::exists?(ls_Path)
			end
			
			unless (lk_Errors.empty?)
				puts "Error#{lk_Errors.size == 1 ? '' : 's'}:"
				puts lk_Errors.join("\n")
				return
			end
			
			lk_OutputFiles.each do |ls_Filename|
				ls_Path = File::join(ls_OutputDirectory, ls_Filename)
				File.open(ls_Path, 'w') do |lk_File|
					lk_File.write(ak_Script.getOutputFile(ls_Ticket, ls_Filename))
				end
			end
		end
=end		
	end
	# TODO: missing md5 check and job deletion on server
end


class RemoteHub < WEBrick::HTTPServlet::AbstractServlet
	def do_POST(request, response)
		response.status = 200
		response['Content-Type'] = 'text/plain'
		ls_Body = request.body.gsub!("\r", '')
		lk_Lines = ls_Body.split("\n")
		ls_Peer = lk_Lines.first.chomp
		lk_Lines.slice!(0)
		
		$gs_Uri = ls_Peer
		
		begin
			$lk_OldStdout = $stdout
			$stdout = StringIO.new
			$lk_OldStderr = $stderr
			$stderr = StringIO.new
			begin
				$gk_Peers[ls_Peer] = DRbObject.new(nil, ls_Peer) unless $gk_Peers.has_key?(ls_Peer)
				handleArguments($gk_Peers[ls_Peer], lk_Lines)
			rescue Exception => e
				puts 'error'
				puts e
			end
		ensure
			response.body = $stdout.string
			$stdout = $lk_OldStdout
			$stderr = $lk_OldStderr
		end
	end
end


if ARGV == ['--hub']
	DRb.start_service
	
	$gk_Peers = Hash.new
	
	server = WEBrick::HTTPServer.new(:Port => 0)
	server.mount "/", RemoteHub
	trap "INT" do server.shutdown end
	puts "REMOTE-HUB-PORT-START#{server.config[:Port]}REMOTE-HUB-PORT-END"
    $stdout.flush
    $stderr.flush
		
	server.start
else
	DRb.start_service
	$gs_Uri = ARGV.first
	lk_Script = DRbObject.new(nil, $gs_Uri)
	ARGV.slice!(0)
	
	begin
		unless lk_Script.proteomatic? == 'proteomatic!'
			puts 'Error: Remote daemon is not a Proteomatic script.'
			exit 1
		end
	rescue DRb::DRbConnError => e
		puts 'Error: Unable to establish connection.'
		exit 1
	end
	
	handleArguments(lk_Script, ARGV)
end
