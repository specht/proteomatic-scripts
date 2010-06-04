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

require 'include/ruby/externaltools'
require 'include/ruby/formats'
require 'include/ruby/misc'
require 'include/ruby/parameters'
require 'drb'
require 'fileutils'
require 'set'
require 'tempfile'
require 'thread'
require 'yaml'
require 'zlib'
require 'uri'
require 'net/http'
require 'digest/md5'
require 'socket'
require 'timeout'


DEFAULT_DAEMON_PORT = 5555
UNSENT_REPORTS_PATH = 'unsent-filetracker-reports'


class StdoutListener
	def initialize(ak_OldDevice = STDOUT)
		@mk_OldDevice = ak_OldDevice
		@ms_Output = ''
	end
	
	def write(args)
		@mk_OldDevice.write(args)
		@ms_Output += args
	end
	
	def get()
		return @ms_Output
	end
	
	def flush()
		@mk_OldDevice.flush()
	end
end


class ProteomaticScriptDaemon
	def initialize(ak_Script)
		@mk_Script = ak_Script
		@ms_ScriptHelp = @mk_Script.help()
		
		@mk_Tickets = Hash.new
		@mk_TicketOrder = Array.new
		@mk_TicketsMutex = Mutex.new

		# set up paths
		@ms_ScriptPath = File.expand_path(File.join(File.dirname(__FILE__), '..'))
		@ms_TempPath = File.join(@ms_ScriptPath, 'jobs', File.basename($0).sub('.rb', ''))
		FileUtils.mkpath(@ms_TempPath)
		
		# find pending jobs
		lk_Pending = Dir::glob(@ms_TempPath + '/*').collect { |x| File.basename(x) }
		lk_Pending.each do |ls_Ticket|
			ls_State = nil
			ls_State = :waiting if File::exists?(File.join(@ms_TempPath, ls_Ticket, 'waiting'))
			ls_State = :finished if File::exists?(File.join(@ms_TempPath, ls_Ticket, 'finished'))
			if File::exists?(File.join(@ms_TempPath, ls_Ticket, 'running'))
				# revert job if it was running while the daemon was shut down
				FileUtils::mv(File.join(@ms_TempPath, ls_Ticket, 'running'), File.join(@ms_TempPath, ls_Ticket, 'waiting'))
				ls_State = :waiting
			end
			@mk_Tickets[ls_Ticket] = ls_State if ls_State
			@mk_TicketOrder.push(ls_Ticket) if ls_State == :waiting
		end
		@mk_TicketOrder.sort! do |x, y|
			File::ctime(File::join(@ms_TempPath, x, 'arguments.yaml')) <=> File::ctime(File::join(@ms_TempPath, y, 'arguments.yaml'))
		end
		
		# start worker thread
		@mk_WorkerThread = Thread.new do
			while true
				ls_NextTicket = nil
				@mk_TicketsMutex.synchronize { ls_NextTicket = @mk_TicketOrder.first }
				
				# go to sleep if no more tickets
				Thread.stop unless ls_NextTicket
				
				if ls_NextTicket
					# fetch and handle next job
					
					# switch to running state
					@mk_TicketsMutex.synchronize { @mk_Tickets[ls_NextTicket] = :running }
					FileUtils::mv(File::join(@ms_TempPath, ls_NextTicket, 'waiting'), File::join(@ms_TempPath, ls_NextTicket, 'running'))
					
					# remove out files, if any (in case the job was once running and then aborted)
					lk_OutFiles = Dir::glob(File::join(@ms_TempPath, ls_NextTicket, 'out', '*'))
					lk_OutFiles.push(File::join(@ms_TempPath, ls_NextTicket, 'stderr.txt'))
					lk_OutFiles.push(File::join(@ms_TempPath, ls_NextTicket, 'stdout.txt'))
					FileUtils::rm_f(lk_OutFiles)
					
					# load and apply arguments
					lk_Arguments = YAML::load_file(File::join(@ms_TempPath, ls_NextTicket, 'arguments.yaml'))
					lk_Arguments = lk_Arguments.select { |x| x[0, 14] != '----ignore----' }
					lk_Arguments.push('-outputDirectory')
					lk_Arguments.push(File::join(@ms_TempPath, ls_NextTicket, 'out'))
					puts lk_Arguments.to_yaml
					lb_Exception = false
					$stdout = File.new(File::join(@ms_TempPath, ls_NextTicket, 'stdout.txt'), 'w')
					$stderr = File.new(File::join(@ms_TempPath, ls_NextTicket, 'stderr.txt'), 'w')
					begin
						@mk_Script.applyArguments(lk_Arguments)
					rescue ProteomaticArgumentException => e
						puts e
						lb_Exception = true
					end
					$stdout.close()
					$stderr.close()
					$stdout = STDOUT
					$stderr = STDERR
					
					# execute job if arguments were good
					unless lb_Exception
						$stdout = File.new(File::join(@ms_TempPath, ls_NextTicket, 'stdout.txt'), 'a')
						$stderr = File.new(File::join(@ms_TempPath, ls_NextTicket, 'stderr.txt'), 'a')
						@mk_Script.run()
						lk_Files = YAML::load_file(File.join(@ms_TempPath, ls_NextTicket, 'output-files.yaml'))
						lk_Files['files'] = @mk_Script.finishOutputFiles()
						lk_Mapping = YAML::load_file(File::join(@ms_TempPath, ls_NextTicket, 'file-mapping.yaml'))
						ls_Path = lk_Mapping[@mk_Script.fileDefiningOutputDirectory()]
						lk_Files['directory'] = File::dirname(ls_Path) if (!lk_Files.has_key?('directory')) && ls_Path
						lk_Files['prefix'] = @mk_Script.param('outputPrefix')
						File.open(File.join(@ms_TempPath, ls_NextTicket, 'output-files.yaml'), 'w') do |lk_File| 
							lk_File.puts lk_Files.to_yaml
						end
						$stdout.close()
						$stderr.close()
						$stdout = STDOUT
						$stderr = STDERR
					end
					
					# switch to finished state
					@mk_TicketsMutex.synchronize do
						@mk_Tickets[ls_NextTicket] = :finished
						@mk_TicketOrder.slice!(0)
					end
					FileUtils::mv(File.join(@ms_TempPath, ls_NextTicket, 'running'), File.join(@ms_TempPath, ls_NextTicket, 'finished'))
				end
			end
		end
		@mk_WorkerThread.priority = -1
	end
	
	def proteomatic?()
		return 'proteomatic!'
	end

	def help()
		return @ms_ScriptHelp
	end

	def submit(ak_Arguments, ak_Files, as_OutputDirectory)
		ls_Ticket = nil
		ls_Letters = 'bcdfghjkmpqrstvwxyz'
		ls_Digits = '0123456789'
		@mk_TicketsMutex.synchronize do
			while ls_Ticket == nil || @mk_Tickets.has_key?(ls_Ticket)
				ls_Ticket = ''
				ls_Ticket += ls_Letters[rand(ls_Letters.size), 1]
				ls_Ticket += ls_Digits[rand(ls_Digits.size), 1]
				ls_Ticket += ls_Digits[rand(ls_Digits.size), 1]
				ls_Ticket += ls_Letters[rand(ls_Letters.size), 1]
			end
			@mk_Tickets[ls_Ticket] = :waiting
		end
		
		FileUtils.mkpath(File.join(@ms_TempPath, ls_Ticket, 'in'))
		FileUtils.mkpath(File.join(@ms_TempPath, ls_Ticket, 'out'))
		lk_FileCount = Hash.new
		lk_FileMapping = Hash.new
		lb_FilesMissing = false
		ak_Files.each do |ls_Path, ls_Contents|
			ls_BaseName = File::basename(ls_Path)
			lk_FileCount[ls_BaseName] ||= -1
			lk_FileCount[ls_BaseName] += 1
			ls_SandboxPath = File.join(@ms_TempPath, ls_Ticket, 'in', lk_FileCount[ls_BaseName].to_s + '-' + ls_BaseName)
			ls_SandboxPath = File.join(@ms_TempPath, ls_Ticket, 'in', ls_BaseName) if (lk_FileCount[ls_BaseName] == 0)
			if ls_Contents == nil
				lb_FilesMissing = true
				File.open(ls_SandboxPath, 'wb') { |lk_File| }
			else
				File.open(ls_SandboxPath, 'wb') { |lk_File| lk_File.write(ls_Contents) }
			end
			ak_Arguments.push(ls_SandboxPath)
			lk_FileMapping[ls_SandboxPath] = ls_Path
		end
		File.open(File.join(@ms_TempPath, ls_Ticket, 'arguments.yaml'), 'w') { |lk_File| lk_File.puts ak_Arguments.to_yaml }
		File.open(File.join(@ms_TempPath, ls_Ticket, 'file-mapping.yaml'), 'w') { |lk_File| lk_File.puts lk_FileMapping.to_yaml }
		lk_OutputFileInfo = Hash.new
		lk_OutputFileInfo['directory'] = as_OutputDirectory if as_OutputDirectory
		File.open(File.join(@ms_TempPath, ls_Ticket, 'output-files.yaml'), 'w') { |lk_File| lk_File.puts lk_OutputFileInfo.to_yaml }
		unless lb_FilesMissing
			File.open(File.join(@ms_TempPath, ls_Ticket, 'waiting'), 'w') { |lk_File| }
			@mk_TicketsMutex.synchronize { @mk_TicketOrder.push(ls_Ticket) }
			@mk_WorkerThread.wakeup
		end
		return ls_Ticket
	end
	
	def submitInputFileChunk(as_Ticket, as_Path, as_Chunk)
		lk_ReverseFileMapping = YAML::load_file(File.join(@ms_TempPath, as_Ticket, 'file-mapping.yaml')).invert
		ls_SandboxPath = lk_ReverseFileMapping[as_Path]
		File::open(ls_SandboxPath, 'ab') { |lk_File| lk_File.write(Zlib::Inflate.inflate(as_Chunk)) }
		#sleep 0.1
	end
	
	def submitInputFilesFinished(as_Ticket)
		File.open(File.join(@ms_TempPath, as_Ticket, 'waiting'), 'w') { |lk_File| }
		@mk_TicketsMutex.synchronize { @mk_TicketOrder.push(as_Ticket) }
		@mk_WorkerThread.wakeup
	end
	
	def queryTicket(as_Ticket)
		lk_Info = Hash.new
		@mk_TicketsMutex.synchronize do
			lk_Info['state'] = @mk_Tickets[as_Ticket].to_s
			lk_Info['state'] ||= 'unknown'
			if @mk_Tickets[as_Ticket] == :waiting
				lk_Info['infront'] = @mk_TicketOrder.index(as_Ticket)
			end
			if @mk_Tickets[as_Ticket] == :finished
				lk_OutputFileInfo = YAML::load(File.read(File.join(@ms_TempPath, as_Ticket, 'output-files.yaml')))
				lk_Info['output'] = lk_OutputFileInfo
				
				# ensure default values
				lk_Info['output']['directory'] ||= ''
				lk_Info['output']['prefix'] ||= ''
				lk_Info['output']['files'] ||= []
			end
		end
		return lk_Info
	end
	
	def finished?(as_Ticket)
		lb_Finished = false
		@mk_TicketsMutex.synchronize { lb_Finished = (@mk_Tickets[as_Ticket] == :finished) }
		return lb_Finished
	end
	
	def outputFileInfo(as_Ticket)
		@mk_TicketsMutex.synchronize { return nil unless @mk_Tickets[as_Ticket] == :finished }
		ls_Path = File::join(@ms_TempPath, as_Ticket, 'output-files.yaml')
		return [] unless File::exists?(ls_Path)
		return YAML::load_file(ls_Path)
	end
	
	def getOutputFile(as_Ticket, as_Filename)
		@mk_TicketsMutex.synchronize { return nil unless @mk_Tickets[as_Ticket] == :finished }
		return File::read(File::join(@ms_TempPath, as_Ticket, 'out', as_Filename))
	end
	
	def getStandardOutput(as_Ticket)
		@mk_TicketsMutex.synchronize { return nil unless @mk_Tickets[as_Ticket] == :finished }
		return File::read(File::join(@ms_TempPath, as_Ticket, 'stdout.txt'))
	end

	def getStandardError(as_Ticket)
		@mk_TicketsMutex.synchronize { return nil unless @mk_Tickets[as_Ticket] == :finished }
		return File::read(File::join(@ms_TempPath, as_Ticket, 'stderr.txt'))
	end
end


class ProteomaticArgumentException < StandardError
end


class ProteomaticScript
	def formatTime(af_Duration)
		if (af_Duration < 60.0)
			return sprintf('%1.1f seconds', af_Duration)
		elsif (af_Duration < 3600.0)
			return sprintf('%d minutes and %d seconds', 
				(af_Duration / 60.0).floor,
				(af_Duration % 60.0).floor)
		else
			return sprintf('%d hours, %d minutes and %d seconds',
				(af_Duration / 3600.0).floor,
				((af_Duration % 3600.0) / 60.0).floor,
				(af_Duration % 60.0).floor)
		end
	end
	
	def initialize()
	
		@mk_TempFiles = Array.new
	
		# flush stdout and stderr every second... TODO: find a better way
		@mk_FlushThread = Thread.new do
			while true
				$stdout.flush
				$stderr.flush
				sleep 1.0
			end
		end
		
		@ms_Platform = determinePlatform()
		@ms_Platform.freeze
		
		@ms_UserName = nil
		@ms_HostName = nil
		
		@ms_UserName = ENV.to_hash['USERNAME'] unless @ms_UserName
		@ms_UserName = ENV.to_hash['USER'] unless @ms_UserName
		@ms_UserName = 'unknown' unless @ms_UserName
		
		@ms_HostName = ENV.to_hash['COMPUTERNAME'] unless @ms_HostName
		unless @ms_HostName
			ls_Result = %x{hostname}
			@ms_HostName = ls_Result if $? == 0
		end
		@ms_HostName = 'unknown' unless @ms_HostName
		
		@ms_UserName = @ms_UserName.dup
		@ms_HostName = @ms_HostName.dup
		
		@ms_UserName.strip!
		@ms_HostName.strip!
		
		@ms_UserName.freeze
		@ms_HostName.freeze
		
		@ms_FileTrackerHost = nil
		@mi_FileTrackerPort = nil
		
		# try to read filetracker config file
		if (File::exists?('config/filetracker.config.yaml'))
			config = YAML::load_file('config/filetracker.config.yaml')
			@ms_FileTrackerHost = config['fileTrackerHost']
			@mi_FileTrackerPort = config['fileTrackerPort']
		end
		
		# see if there's a filetracker configuration on the command line
		if ARGV.include?('--useFileTracker')
			fileTrackerHostAndPort = ARGV[ARGV.index('--useFileTracker') + 1]
			ARGV.slice!(ARGV.index('--useFileTracker'), 2)
			fileTrackerHostAndPortList = fileTrackerHostAndPort.split(':')
			@ms_FileTrackerHost = fileTrackerHostAndPortList[0]
			@mi_FileTrackerPort = fileTrackerHostAndPortList[1].to_i
		end
		
        # see if there's a parameter in ARGV that defines where external tools 
        # should be located
        if ARGV.include?('--extToolsPath')
            path = ARGV[ARGV.index('--extToolsPath') + 1]
            ARGV.slice!(ARGV.index('--extToolsPath'), 2)
            ExternalTools::setExtToolsPath(path)
        end
        
		@ms_Version = File::read('include/ruby/version.rb').strip
		@ms_Version.freeze
		
		@mk_StartTime = Time.now
		
		loadDescription()
		
		if ARGV == ['--resolveDependencies']
			resolveDependencies()
			exit 0
		end
		
		if (@mb_NeedsConfig && !@mb_HasConfig)
			puts "Error: This script needs a configuration file. Please check the config directory for a template and instructions."
			exit 1
		end
		
		if ARGV == ['--showFileDependencies']
			showFileDependencies()
			exit 0
		end
		
        begin
            setupParameters()
        rescue ProteomaticArgumentException => e
            puts e
            exit 1
        end
		handleArguments()
		
		if @mb_Daemon
			resolveDependencies()
			lk_Server = TCPServer.new('', @mi_DaemonPort);
			puts "#{@ms_Title} daemon listening on port #{@mi_DaemonPort}."
			while (lk_Session = lk_Server.accept)
				Thread.new(lk_Session) do |lk_ThisSession|
					begin
						handleTcpRequest(lk_ThisSession)
					ensure
						lk_ThisSession.close
					end
				end
			end
		
# 			DRb.start_service(@ms_DaemonUri, ProteomaticScriptDaemon.new(self))
# 			puts "#{@ms_Title} daemon listening at #{DRb.uri}"
# 			DRb.thread.join
		else
			lk_Listener = StdoutListener.new(STDOUT)
			$stdout = lk_Listener
			begin
				applyArguments(ARGV)
			rescue ProteomaticArgumentException => e
				puts e
				exit 1
			end
			run()
			finishOutputFiles()
			@mk_EndTime = Time.now
			puts "Execution took #{formatTime(@mk_EndTime - @mk_StartTime)}."
			$stdout = STDOUT
			@ms_EavesdroppedOutput = lk_Listener.get()
			submitRunToFileTracker() if @ms_FileTrackerHost
		end
	end
	
	def help()
		ls_Result = ''
		ls_Result += "#{underline("#{@ms_Title} (a Proteomatic script, version #{@ms_Version})", '=')}\n"
		# strip HTML tags from description and squeeze spaces
		ls_Result += wordwrap("#{@ms_Description.gsub(/<\/?[^>]*>/, '').squeeze(' ')}") + "\n" unless @ms_Description.empty?
		ls_Result += "Usage:\n    ruby #{$0} [options/parameters]"
		ls_Result += " [input files]" unless @mk_Input['groupOrder'].empty?
		ls_Result += "\n\n"
		ls_Result += indent(wordwrap("Options:\n--help\n     print this help\n\n" +
			"--proposePrefix\n     propose a prefix depending on the input files specified\n\n" +
			"--useFileTracker [host:port]\n     specify a filetracker, this overrides filetracker.conf.yaml\n\n" +
			"--daemon [port]\n     run this script as a daemon, default port is #{DEFAULT_DAEMON_PORT}"), 4, false)
		ls_Result += "\n"
		ls_Result += @mk_Parameters.helpString()
		if @mk_Input
			ls_Result += "#{underline('Input files', '-')}\n" unless @mk_Input['groupOrder'].empty?
			@mk_Input['groupOrder'].each do |ls_Group|
				ls_Range = ''
				ls_Range += 'min' if @mk_Input['groups'][ls_Group]['min']
				ls_Range += 'max' if @mk_Input['groups'][ls_Group]['max']
				ls_Result += '- '
				if (ls_Range == 'min')
					ls_Result += "at least #{@mk_Input['groups'][ls_Group]['min']} "
					ls_FileLabel = "file#{@mk_Input['groups'][ls_Group]['min'] != 1 ? 's' : ''} "
				elsif (ls_Range == 'max')
					ls_Result += "at most #{@mk_Input['groups'][ls_Group]['max']} "
					ls_FileLabel = "file#{@mk_Input['groups'][ls_Group]['max'] != 1 ? 's' : ''} "
				elsif (ls_Range == 'minmax')
					if (@mk_Input['groups'][ls_Group]['min'] == @mk_Input['groups'][ls_Group]['max'])
						ls_Result += "exactly #{@mk_Input['groups'][ls_Group]['min']} "
						ls_FileLabel = "file#{@mk_Input['groups'][ls_Group]['min'] != 1 ? 's' : ''} "
					else
						ls_Result += "at least #{@mk_Input['groups'][ls_Group]['min']}, but no more than #{@mk_Input['groups'][ls_Group]['max']} "
						ls_FileLabel = 'files '
					end
				else
					ls_FileLabel = 'files '
				end
				ls_Result += 'optional: ' if (ls_Range == '')
				ls_Result += "#{@mk_Input['groups'][ls_Group]['label']} #{ls_FileLabel}"
				ls_Result += "\n"
				ls_Line = "format: #{@mk_Input['groups'][ls_Group]['formats'].collect { |x| info = formatInfo(x); "#{info['description']} (#{info['extensions'].join('|')})" }.join(', ')}"
				ls_Result += indent(wordwrap(ls_Line), 2, true) + "\n"
				ls_Result += "\n"
			end
		end
		unless @mk_Input['ambiguousFormats'].empty?
# 				ls_Line = "-#{ls_Group}: force assignment of following files to this group"
# 				ls_Result += indent(wordwrap(ls_Line), 2, true) + "\n"
			ls_Result += "#{underline('Input file ambiguities', '-')}\n"
			ls_Result += wordwrap("Because some input file formats appear in multiple input file groups, files in some input formats must be manually assigned to a certain input file group by preceding the filenames with the appropriate switches.")
			ls_Result += "\n"
			ls_Result += wordwrap("Affected input file formats:")
			ls_Result += "\n"
			@mk_Input['ambiguousFormats'].to_a.sort.each do |ls_Format|
				lk_FormatInfo = formatInfo(ls_Format)
				ls_Result += wordwrap("- #{lk_FormatInfo['description']} (#{lk_FormatInfo['extensions'].join('|')})")
				ls_Result += "\n"
			end
			ls_Result += wordwrap("Input file group assignment switches:")
			ls_Result += "\n"
			@mk_Input['groupOrder'].each do |ls_Group|
				next if (Set.new(@mk_Input['groups'][ls_Group]['formats']) & @mk_Input['ambiguousFormats']).empty?
				ls_Result += wordwrap("-#{ls_Group}: subsequent files are interpreted as #{@mk_Input['groups'][ls_Group]['label']} files")
				ls_Result += "\n"
			end
		end
		if @mk_Input && @ms_DefaultOutputDirectoryGroup
			ls_Result += "#{underline('Output directory', '-')}\n"
			ls_Result += wordwrap("Unless an output directory is specified, the output files will be written to the directory of the first #{@mk_Input['groups'][@ms_DefaultOutputDirectoryGroup]['label']} file.")
			ls_Result += "\n"
		end
		return ls_Result
	end
	
    def yamlInfo(ab_Short = false)
        ls_Result = ''
        ls_Result << "---yamlInfo\n"
        info = Hash.new
        info['title'] = @ms_Title
        info['description'] = @ms_Description
        info['group'] = @ms_Group
        inputFormats = []
        @mk_Input['groups'].values.each do |formatInfo|
            formatInfo['formats'].each do |format|
                inputFormats += formatInfo(format)['extensions']
            end
        end
        inputFormats.sort!
        inputFormats.uniq!
        info['inputExtensions'] = inputFormats.join('|')
        if ARGV.include?('--short')
            ls_Result << info.to_yaml
            return ls_Result
        end
            
        info['type'] = @ms_ScriptType
        if (@ms_ScriptType == 'converter')
            info['converterKey'] = @mk_Output.values.first['key']
            info['converterLabel'] = @mk_Output.values.first['label']
            info['converterFilename'] = @mk_Output.values.first['filename']
        end
        unless ab_Short
            info['parameters'] = @mk_Parameters.yamlInfo()
        end
        
        if @mk_Input
            info['input'] = Array.new
            @mk_Input['groupOrder'].each do |ls_Group|
                inputInfo = Hash.new
                inputInfo['key'] = @mk_Input['groups'][ls_Group]['key']
                inputInfo['label'] = @mk_Input['groups'][ls_Group]['label']
                ls_Format = "#{@mk_Input['groups'][ls_Group]['formats'].collect { |x| formatInfo(x)['extensions'] }.flatten.uniq.sort.join(' | ')}"
                ls_Range = ''
                ls_Range += 'min' if @mk_Input['groups'][ls_Group]['min']
                ls_Range += 'max' if @mk_Input['groups'][ls_Group]['max']
                ls_FileLabel = ''
                description = ''
                if (ls_Range == 'min')
                    description += "at least #{@mk_Input['groups'][ls_Group]['min']} "
                    ls_FileLabel = "file#{@mk_Input['groups'][ls_Group]['min'] != 1 ? 's' : ''} "
                elsif (ls_Range == 'max')
                    description += "at most #{@mk_Input['groups'][ls_Group]['max']} "
                    ls_FileLabel = "file#{@mk_Input['groups'][ls_Group]['max'] != 1 ? 's' : ''} "
                elsif (ls_Range == 'minmax')
                    if (@mk_Input['groups'][ls_Group]['min'] == @mk_Input['groups'][ls_Group]['max'])
                        description += "exactly #{@mk_Input['groups'][ls_Group]['min']} "
                        ls_FileLabel = "file#{@mk_Input['groups'][ls_Group]['min'] != 1 ? 's' : ''} "
                    else
                        description += "at least #{@mk_Input['groups'][ls_Group]['min']}, but no more than #{@mk_Input['groups'][ls_Group]['max']} "
                        ls_FileLabel = 'files '
                    end
                else
                    ls_FileLabel = 'files '
                end
                description += 'optional: ' if (ls_Range == '')
                description += "#{@mk_Input['groups'][ls_Group]['label']} #{ls_FileLabel}"
                description += "(#{ls_Format})"
                inputInfo['description'] = description
                inputInfo['extensions'] = @mk_Input['groups'][ls_Group]['formats'].collect { |x| formatInfo(x)['extensions'] }.flatten.uniq.sort.join('/')
                inputInfo['min'] = @mk_Input['groups'][ls_Group]['min'] if @mk_Input['groups'][ls_Group]['min']
                inputInfo['max'] = @mk_Input['groups'][ls_Group]['max'] if @mk_Input['groups'][ls_Group]['max']
                info['input'] << inputInfo
            end
            if @ms_DefaultOutputDirectoryGroup
                info['defaultOutputDirectory'] = @mk_Input['groups'][@ms_DefaultOutputDirectoryGroup]['key']
            end
            if @mk_ScriptProperties['proposePrefix']
                info['proposePrefixList'] = Array.new
                @mk_ScriptProperties['proposePrefix'].each do |x|
                    info['proposePrefixList'] << x
                end
            end
            unless @mk_Input['ambiguousFormats'].empty?
                info['ambiguousInputGroups'] = Array.new
                @mk_Input['groupOrder'].each do |ls_Group|
                    next if (Set.new(@mk_Input['groups'][ls_Group]['formats']) & @mk_Input['ambiguousFormats']).empty?
                    info['ambiguousInputGroups'] << ls_Group
                end
            end
        end
        ls_Result << info.to_yaml
        return ls_Result
    end
    
	def handleArguments()
		if ARGV.first == '--daemon'
			@mb_Daemon = true
			@mi_DaemonPort = DEFAULT_DAEMON_PORT
			@mi_DaemonPort = ARGV[1].to_i if ARGV.size > 1
		end
        if ARGV.first == '---yamlInfo'
            puts yamlInfo(ARGV.include?('--short'))
            exit 0
        end
		if ARGV == ['--help']
			puts help()
			exit 0
		end		
	end
	private :handleArguments

	def resolveDependencies()
		if @mk_ScriptProperties.include?('needs')
			@mk_ScriptProperties['needs'].each do |ls_ExtTool|
				# skip if 'config' and not a proper 'package.program' tool
				next unless ls_ExtTool[0, 4] == 'ext.'
				ExternalTools::install(ls_ExtTool) unless ExternalTools::installed?(ls_ExtTool)
			end
		end
	end
	private :resolveDependencies
	
	def showFileDependencies()
		puts $0
		puts "include/properties/#{@ms_ScriptName}.yaml"
		ls_ConfigPath = File::join('config', "#{@ms_ScriptName}.config.yaml")
		puts ls_ConfigPath if @mb_NeedsConfig && File::exists?(ls_ConfigPath)
		if @mk_ScriptProperties.include?('needs')
			@mk_ScriptProperties['needs'].each do |ls_Need|
				next if ls_Need == 'config'
				puts Dir[File::join('include', 'properties', "#{ls_Need}*")].join("\n")
			end
		end
		if (@mk_ScriptProperties.has_key?('externalParameters'))
			@mk_ScriptProperties['externalParameters'].each do |ls_ExtTool|
				puts("include/cli-tools-atlas/packages/ext.#{ls_ExtTool}.yaml")
			end
		end
	end
	private :showFileDependencies

	
	def mergeFilenames(ak_Names)
		return nil if ak_Names.empty?
		lk_Names = ak_Names.dup

		# split into numbers/non-numbers
		ls_AllPattern = nil
		lk_AllParts = nil
		lk_Names.each do |x|
			ls_Pattern = nil
			lk_Parts = Array.new
			(0...x.size).each do |i|
				lb_IsDigit = (/\d/ =~ x[i, 1])
				ls_Marker = lb_IsDigit ? '0' : 'a'
				unless ls_Pattern
					ls_Pattern = ls_Marker 
					lk_Parts.push('')
				end
				unless ls_Pattern[-1, 1] == ls_Marker
					ls_Pattern += ls_Marker 
					lk_Parts.push('')
				end
				lk_Parts.last << x[i, 1]
			end
	
			# check whether pattern is constant
			if ls_AllPattern
				if (ls_AllPattern != ls_Pattern)
					return nil
				end
			else
				ls_AllPattern = ls_Pattern
			end
	
			# convert number strings to numbers
			#(0...lk_Parts.size).each { |i| lk_Parts[i] = lk_Parts[i].to_i if ls_Pattern[i, 1] == '0' }

			# create part sets when they don't exist on first iteration
			unless lk_AllParts
				lk_AllParts = Array.new
				(0...lk_Parts.size).each { |i| lk_AllParts.push(Set.new) }
			end
	
			# insert parts into part sets
			(0...lk_Parts.size).each { |i| lk_AllParts[i].add(lk_Parts[i]) }
		end

		ls_MergedName = ''

		(0...ls_AllPattern.size).each do |i|
			lk_Part = lk_AllParts[i].to_a
			if ls_AllPattern[i, 1] == 'a'
				lk_Part.sort!
			else
				lk_Part.sort! { |a, b| a.to_i <=> b.to_i }
			end
			if (lk_Part.size == 1)
				ls_MergedName << lk_Part.first.to_s
			else
				if (ls_AllPattern[i, 1] == '0')
					# we have multiple entries and it's a number part, try to find ranges!
					ls_Start = nil
					ls_Stop = nil
					ls_Last = nil
					lk_OldPart = lk_Part.dup
					lk_Part = Array.new
					lk_OldPart.each do |si|
						li_Number = si.to_i
						unless ls_Start 
							ls_Start = si
							ls_Stop = si 
							ls_Last = si
							next
						end
						if li_Number == ls_Last.to_i + 1
							# extend range
							ls_Stop = si
							ls_Last = si
							next
						else
							if (ls_Start.to_i == ls_Stop.to_i)
								lk_Part << "#{ls_Start}"
							elsif(ls_Start.to_i + 1 == ls_Stop.to_i)
								lk_Part << "#{ls_Start},#{ls_Stop}"
							else
								lk_Part << "#{ls_Start}-#{ls_Stop}"
							end
							ls_Start = si
							ls_Last = si
							ls_Stop = si
						end
					end
					if (ls_Start.to_i == ls_Stop.to_i)
						lk_Part << "#{ls_Start}"
					elsif(ls_Start.to_i + 1 == ls_Stop.to_i)
						lk_Part << "#{ls_Start},#{ls_Stop}"
					else
						lk_Part << "#{ls_Start}-#{ls_Stop}"
					end
				end
				ls_MergedName << lk_Part.join(',')
			end
		end
		return ls_MergedName
	end
	private :mergeFilenames


	def loadDescription()
		# load script parameters and external tools
		@ms_ScriptName = File.basename($0).sub('.defunct.', '.').sub('.rb', '')
		@mk_ScriptProperties = YAML::load_file("include/properties/#{@ms_ScriptName}.yaml")
		unless @mk_ScriptProperties.has_key?('title')
			puts 'Internal error: Script has no title.'
			exit 1
		end
		unless @mk_ScriptProperties.has_key?('group')
			puts 'Internal error: Script has no group.'
			exit 1
		end
		@ms_ScriptType = nil
		@ms_ScriptType = @mk_ScriptProperties['type']
		unless (@ms_ScriptType == 'processor' || @ms_ScriptType == 'converter')
			puts 'Internal error: No type or invalid type defined for this script.'
			exit 1
		end
		@mk_ScriptProperties.default = ''
		@ms_Description = @mk_ScriptProperties['description'].strip
		@ms_Description.freeze
		@ms_Title = @mk_ScriptProperties['title']
		@ms_Title.freeze
		@ms_Group = @mk_ScriptProperties['group']
		@ms_Group.freeze
		if @mk_ScriptProperties['needs'] && @mk_ScriptProperties['needs'].include?('config')
			@mb_NeedsConfig = true
		else
			@mb_NeedsConfig = false
		end
		@mb_HasConfig = File::exists?(File::join('config', "#{@ms_ScriptName}.config.yaml"))
	end
	private :loadDescription
	
	def setupParameters()
		lk_Errors = Array.new
		
		# check dependencies if called from GUI
		if @mk_ScriptProperties.has_key?('needs')
			if (ARGV.first == '---yamlInfo') && (!ARGV.include?('--short'))
				ls_Response = ''
				@mk_ScriptProperties['needs'].each do |ls_ExtTool|
					next unless ls_ExtTool[0, 4] == 'ext.'
					ls_Response << "#{ExternalTools::packageTitle(ls_ExtTool)}\n" unless ExternalTools::installed?(ls_ExtTool)
				end
				unless ls_Response.empty?
					puts '---hasUnresolvedDependencies'
					puts ls_Response
					exit 0
				end
			end
		end
		
		# check whether we have prefix proposal settings, if not, generate one
		if (!@mk_ScriptProperties.has_key?('proposePrefix')) || (@mk_ScriptProperties['proposePrefix'].empty?)
			@mk_ScriptProperties['proposePrefix'] = [@mk_ScriptProperties['defaultOutputDirectory']]
		end
			
		raise ProteomaticArgumentException, "Error#{lk_Errors.size > 1 ? "s:\n": ": "}" + lk_Errors.join("\n") unless lk_Errors.empty?
		lk_Errors = Array.new
		
		@mk_Parameters = Parameters.new

		# add external tool parameters if desired
        unless ((ARGV.first == '---yamlInfo') && (ARGV.include?('--short')))
            if (@mk_ScriptProperties.has_key?('externalParameters'))
                @mk_ScriptProperties['externalParameters'].each do |ls_ExtTool|
                    lk_Properties = YAML::load_file("include/cli-tools-atlas/packages/ext.#{ls_ExtTool}.yaml")
                    lk_Properties['parameters'].each do |lk_Parameter| 
                        lk_Parameter['key'] = ls_ExtTool + '.' + lk_Parameter['key']
                        @mk_Parameters.addParameter(lk_Parameter, ls_ExtTool)
                    end
                end
            end
		
            # add script parameters
            if @mk_ScriptProperties.include?('parameters')
                @mk_ScriptProperties['parameters'].each do |lk_Parameter| 
                    if (lk_Parameter['key'][0, 5] == 'input' || lk_Parameter['key'][0, 6] == 'output')
                        puts "Internal error: Parameter key must not start with 'input' or 'output'."
                        puts lk_Parameter.to_yaml
                        exit 1
                    end
                    @mk_Parameters.addParameter(lk_Parameter)
                end
            end
        end
		
		# handle filetracker options
		@mk_DontMd5InputFiles = Array.new
		@mk_DontMd5OutputFiles = Array.new
		if @mk_ScriptProperties.include?('filetracker')
			@mk_ScriptProperties['filetracker'].each do |lk_Parameter|
				@mk_DontMd5InputFiles = lk_Parameter.values.first if lk_Parameter.keys.first == 'dontMd5InputFiles'
				@mk_DontMd5OutputFiles = lk_Parameter.values.first if lk_Parameter.keys.first == 'dontMd5OutputFiles'
			end
		end
		
		# handle input files
		lk_InputFormats = Hash.new
		lk_InputGroups = Hash.new
		lk_InputGroupOrder = Array.new
		lk_AmbiguousFormats = Set.new
		if @mk_ScriptProperties.include?('input')
			@mk_ScriptProperties['input'].each do |lk_InputGroup|
				unless lk_InputGroup.has_key?('key')
					puts "Internal error: Input group has no key."
					exit 1
				end
				unless lk_InputGroup['formats'].class == Array
                    if @mk_ScriptProperties['input'].size > 1
                        puts "Internal error: 'formats' must be defined if there is more than one input file group."
                        exit 1
                    else
                        lk_InputGroup['formats'] = ['']
                    end
				end
				lk_InputGroups[lk_InputGroup['key']] = lk_InputGroup
				lk_InputGroupOrder.push(lk_InputGroup['key'])
                if lk_InputGroup['formats']
                    lk_InputGroup['formats'].each do |ls_Format|
                        assertFormat(ls_Format)
                        if lk_InputFormats.has_key?(ls_Format)
                            lk_AmbiguousFormats.add(ls_Format)
                            lk_InputFormats.delete(ls_Format)
                        end
                        lk_InputFormats[ls_Format] = lk_InputGroup['key'] unless lk_AmbiguousFormats.include?(ls_Format)
                    end
                end
			end
		end
		@mk_Input = Hash.new
		@mk_Input['groups'] = lk_InputGroups
		@mk_Input['groupOrder'] = lk_InputGroupOrder
		@mk_Input['ambiguousFormats'] = lk_AmbiguousFormats
		@mk_Input.freeze

		# handle output files
		#if @mk_ScriptProperties.has_key?('output')
			lk_Directory = {'group' => 'Output files', 'key' => 'outputDirectory', 
				'label' => 'Output directory', 'type' => 'string', 'default' => ''}
			@mk_Parameters.addParameter(lk_Directory)
			lk_Prefix = {'group' => 'Output files', 'key' => 'outputPrefix', 
				'label' => 'Output file prefix', 'type' => 'string', 'default' => ''}
			@mk_Parameters.addParameter(lk_Prefix)
		#end

		lk_OutputFiles = Hash.new
		if @mk_ScriptProperties.include?('output')
			@mk_ScriptProperties['output'].each do |lk_OutputFile|
				if (@ms_ScriptType == 'converter' && (!lk_OutputFiles.empty?))
					puts 'Internal error: Only one output file group allowed for converter scripts.'
					exit 1
				end
				unless lk_OutputFile.has_key?('key')
					puts "Internal error: Output file has no key."
					exit 1
				end
				ls_Key = lk_OutputFile['key']
				ls_Label = lk_OutputFile['label']
				lk_OutputFiles[ls_Key] = lk_OutputFile
				assertFormat(lk_OutputFile['format'])
				if (@ms_ScriptType == 'processor')
					ls_Key = lk_OutputFile['key']
					ls_Key[0, 1] = ls_Key[0, 1].upcase
					lk_WriteFlag = {'group' => 'Output files', 'key' => "outputWrite#{ls_Key}",
						'label' => ls_Label, 'type' => 'flag',
						'filename' => lk_OutputFile['filename']}
					if (lk_OutputFile.has_key?('force'))
						lk_WriteFlag['force'] = lk_OutputFile['force'] == true ? 'yes' : 'no'
						lk_WriteFlag['default'] = lk_OutputFile['force'] == true ? 'yes' : 'no'
					else
						lk_WriteFlag['default'] = lk_OutputFile['default'] == true ? 'yes' : 'no'
					end
					lk_WriteFlag['description'] = "Write #{ls_Label} (#{lk_WriteFlag['filename']})"
					@mk_Parameters.addParameter(lk_WriteFlag)
				end
			end
		end
		
		@mk_Parameters.checkSanity()
		
		@mk_Output = lk_OutputFiles
		@mk_Output.freeze

		# check if there's a default output directory if output files 
		# are to be written, but only do this if we have input files.
		# if there are no input files and the script creates data from
		# scratch, there's no default output directory
		unless @mk_Input['groups'].empty?
			if @mk_ScriptProperties.has_key?('output')
				if !@mk_ScriptProperties.has_key?('defaultOutputDirectory')
					puts "Internal error: No default output directory specified for this script."
					exit 1
				end
				@ms_DefaultOutputDirectoryGroup = @mk_ScriptProperties['defaultOutputDirectory']
				if !@mk_Input['groups'].has_key?(@ms_DefaultOutputDirectoryGroup)
					puts "Internal error: Invalid default output directory specified for this script."
					exit 1
				end
				
				# check whether prefix proposal entries are sane
				@mk_ScriptProperties['proposePrefix'].each do |x|
					unless @mk_Input['groups'].has_key?(x)
						puts "Script error: proposePrefix contains non-existent input group."
						exit 1
					end
				end
			end
		end
		raise ProteomaticArgumentException, "Error#{lk_Errors.size > 1 ? "s:\n": ": "}" + lk_Errors.join("\n") unless lk_Errors.empty?
	end
	private :loadDescription

	def applyArguments(ak_Arguments)
		lk_Arguments = ak_Arguments.dup
		
		lb_ProposePrefix = false
		if lk_Arguments.include?('--proposePrefix')
			lk_Arguments.delete('--proposePrefix')
			lb_ProposePrefix = true
		end
		
		# reset parameters
		@mk_Parameters.keys().each { |ls_Key| @mk_Parameters.reset(ls_Key) }
		
		# apply profiles
		lk_ProfileMix = Hash.new
		lk_AppliedProfiles = Array.new
		while lk_Arguments.include?('--applyProfile')
			li_Index = lk_Arguments.index('--applyProfile')
			ls_ProfilePath = lk_Arguments[li_Index + 1]
			lk_ApplyProfile = YAML::load_file(ls_ProfilePath)
			lb_Ok = false
			if lk_ApplyProfile['content'].class == Hash
				if lk_ApplyProfile['content']['settings'].class == Hash
					lb_Ok = true
					lk_AppliedProfiles << lk_ApplyProfile['content']['title']
					lk_ApplyProfile['content']['settings'].each_pair do |ls_Key, ls_Value|
						lk_ProfileMix[ls_Key] ||= Set.new
 						lk_ProfileMix[ls_Key] << ls_Value
					end
				end
			end
			unless lb_Ok
				puts "Error: Invalid profile in #{ls_ProfilePath}."
				exit 1
			end
			lk_Arguments.delete_at(li_Index)
			lk_Arguments.delete_at(li_Index)
		end
		unless lk_ProfileMix.empty?
			puts "Applying #{lk_AppliedProfiles.join(', ')} profile#{lk_AppliedProfiles.size > 1 ? 's' : ''}."
			lk_OldKeys = Set.new(lk_ProfileMix.keys)
			lk_ProfileMix.reject! { |ls_Key, lk_Values| lk_Values.size > 1 }
			lk_DeletedKeys = lk_OldKeys - Set.new(lk_ProfileMix.keys)
			unless lk_DeletedKeys.empty?
				puts "...the following keys were ignored due to ambiguity: #{lk_DeletedKeys.to_a.sort.to_yaml.sub('---', '')}"
			end
			# apply profile mix
			lk_ProfileMix.each_key { |ls_Key| lk_ProfileMix[ls_Key] = lk_ProfileMix[ls_Key].to_a.first }
			lk_ProfileMix.each_pair do |ls_Key, ls_Value|
				@mk_Parameters.set(ls_Key, ls_Value)
			end
		end

		# digest command line parameters
		@mk_Parameters.applyParameters(lk_Arguments)
		@param = Hash.new
		@mk_Parameters.keys().each { |ls_Key| @param[ls_Key.intern] = @mk_Parameters.value(ls_Key) }
		
		lk_Files = lk_Arguments.dup
		# check whether all files are there if not in propose prefix mode
		unless lb_ProposePrefix
			lk_Files.each do |ls_Path|
				next if ls_Path[0, 1] == '-' && @mk_Input['groups'].include?(ls_Path[1, ls_Path.size - 1])
				unless File::file?(ls_Path)
					puts "Error: Unable to open file #{ls_Path}."
					exit 1
				end
			end
		end
		
		lk_Arguments.clear
		lk_Directories = [@param['outputDirectory'.intern]]
		lk_Directories = Array.new if !@param['outputDirectory'.intern] || @param['outputDirectory'.intern].empty?

		lk_Errors = Array.new
		lk_UnusedFiles = Array.new
		
		# determine input files
		@input = Hash.new
		
		@mk_Input['groups'].each { |ls_Group, lk_Group|	@input[ls_Group.intern] = Array.new }
		
		# @inputFormat stores the format of each input file
		ls_DefaultInputGroup = nil
		@inputFormat = Hash.new
		lk_Files.each do |ls_Path|
			if (ls_Path[0, 1] == '-')
				ls_Group = ls_Path[1, ls_Path.size - 1]
				ls_DefaultInputGroup = ls_Group
				next
			end
			ls_Group, ls_Format = findGroupForFile(ls_Path)
			if (!ls_Group) && ls_DefaultInputGroup
				ls_Group = ls_DefaultInputGroup
				ls_Format = findFormatForFile(ls_Path)
			end
			if (ls_Group)
				@input[ls_Group.intern] ||= Array.new
				@input[ls_Group.intern].push(ls_Path)
				@inputFormat[ls_Path] = ls_Format
			else
				lk_UnusedFiles.push(ls_Path)
			end
		end
		
		unless lk_UnusedFiles.empty?
			puts "Warning: The following files have been specified but were ignored:\n#{lk_UnusedFiles.join("\n")}"
		end

		# check input files min/max conditions
		@mk_Input['groups'].each do |ls_Group, lk_Group|
            ls_Format = nil
            if @mk_Input['groups'][ls_Group]['formats']
                ls_Format = "#{@mk_Input['groups'][ls_Group]['formats'].collect { |x| formatInfo(x)['extensions'] }.flatten.uniq.sort.join('|')}"
            end
			li_Min = lk_Group['min']
			if li_Min && (!@input.has_key?(ls_Group.intern) || @input[ls_Group.intern].size < li_Min)
				lk_Errors.push("At least #{li_Min} #{lk_Group['label']} file#{li_Min == 1 ? " (#{ls_Format}) is" : "s #{ls_Format} are"} required.")
			end
			li_Max = lk_Group['max']
			if li_Max && @input.has_key?(ls_Group.intern) && @input[ls_Group.intern].size > li_Max
				lk_Errors.push("At most #{li_Min} #{lk_Group['label']} file#{li_Min == 1 ? " (#{ls_Format}) is" : "s (#{ls_Format}) are"} allowed.")
			end
		end

		# determine output files
		@output = Hash.new
		ls_OutputDirectory = nil
		@ms_FileDefiningOutputDirectory = nil
		unless @ms_DefaultOutputDirectoryGroup == nil || @input.empty?
			if @input[@ms_DefaultOutputDirectoryGroup.intern].class == Array
				@ms_FileDefiningOutputDirectory = @input[@ms_DefaultOutputDirectoryGroup.intern].first 
			end
		end
		
		unless lk_Directories.empty?
			ls_OutputDirectory = lk_Directories.first
		else
			ls_OutputDirectory = File::dirname(@ms_FileDefiningOutputDirectory) if @ms_FileDefiningOutputDirectory
		end
		
		if lb_ProposePrefix
			lk_Prefix = Array.new
			@mk_ScriptProperties['proposePrefix'].each do |ls_Group|
				lk_PrefixFiles = @input[ls_Group.intern]
				lk_PrefixFiles.collect! { |x| File::basename(x).split('.').first }
				ls_Merged = mergeFilenames(lk_PrefixFiles)
				unless ls_Merged
					puts 'Sorry, but Proteomatic is unable to propose a catchy prefix.'
					exit 1
				end
				lk_Prefix << ls_Merged
			end
			lk_Prefix.reject! { |x| x.strip.empty? }
			ls_Prefix = lk_Prefix.join('-')
			ls_Prefix << '-' unless ls_Prefix.empty?
			puts '--proposePrefix'
			puts ls_Prefix
			exit 0
		end
        
        # make sure that the output prefix does not contain / or \
        if @param[:outputPrefix]
            if @param[:outputPrefix].include?('/') || @param[:outputPrefix].include?('\\')
                puts "Error: The output prefix must not contain slashes (/) or backslashes (\\)."
                puts "The output prefix you specified is: #{@param[:outputPrefix]}"
                exit 1
            end
        end

		if ls_OutputDirectory == nil && !@mk_Output.empty?
			lk_Errors.push("Unable to determine output directory.")
		else
			if (@ms_ScriptType == 'processor')
				@mk_Output.each do |ls_Key, lk_OutputFile|
					ls_FirstUpKey = ls_Key.dup
					ls_FirstUpKey[0, 1] = ls_FirstUpKey[0, 1].upcase
					if @param["outputWrite#{ls_FirstUpKey}".intern]
						ls_Path = File.join(ls_OutputDirectory, @param['outputPrefix'.intern] + lk_OutputFile['filename'])
						# ignore prefix if in daemon mode
						ls_Path = File.join(ls_OutputDirectory, lk_OutputFile['filename']) if @mb_Daemon
						@output[ls_Key.intern] = ls_Path
					end
				end
			elsif (@ms_ScriptType == 'converter')
				@mk_Output.keys.each do |ls_OutputGroup|
					lk_ExistingFiles = Array.new
					@input[ls_OutputGroup.intern].each do |ls_Path|
						ls_Directory = File::dirname(ls_Path)
						ls_Directory = ls_OutputDirectory if ls_OutputDirectory
						ls_Filename = File::basename(ls_Path).dup
                        lk_FilenameSplit = ls_Filename.split('.')
                        ls_Basename = lk_FilenameSplit[0]
                        ls_Extension = ''
                        ls_Extension = lk_FilenameSplit[1, lk_FilenameSplit.size - 1].join('.') if lk_FilenameSplit.size > 1
						ls_OutFilename = @mk_Output[ls_OutputGroup]['filename'].dup
                        ls_OutFilename.gsub!('#{basename}', ls_Basename)
                        ls_OutFilename.gsub!('#{extension}', ls_Extension)
                        ls_OutFilename.gsub!('#{filename}', ls_Filename)
						@param.keys.each do |ls_Param|
							ls_OutFilename.gsub!('#{' + ls_Param.to_s + '}', "#{@param[ls_Param]}")
						end
						ls_OutPath = File::join(ls_Directory, @param['outputPrefix'.intern] + ls_OutFilename)
						if (File::exists?(ls_OutPath))
							lk_ExistingFiles.push(ls_Path)
							puts "Notice: #{ls_OutPath} already exists - #{ls_Path} will be skipped."
						else
							@output[ls_Path] = ls_OutPath
						end
					end
					# remove input files for which the output file already exists
					lk_ExistingFiles.each { |ls_Path| @input[ls_OutputGroup.intern].delete(ls_Path) }
				end
			end
		end
		@outputDirectory = ls_OutputDirectory

		if (@ms_ScriptType == 'processor')
			# check if output files already exist
			@output.each_value do |ls_Path|
				lk_Errors.push("#{ls_Path} already exists. I won't overwrite this file.") if File::exists?(ls_Path)
			end
		end
		
		# add .proteomatic.part to each output file
		@output.each_key { |ls_Key| @output[ls_Key] += '.proteomatic.part' }

		raise ProteomaticArgumentException, "Error#{lk_Errors.size > 1 ? "s:\n": ": "}" + lk_Errors.join("\n") unless lk_Errors.empty?
		
		if (lk_Arguments.include?('--dryRun'))
			puts 'Dry run ok. Stopping.'
			exit 0
		end
	end
	
	
	def finishOutputFiles()
		lk_Files = Array.new
		@output.each_key do |ls_Key| 
			ls_RealName = @output[ls_Key].sub('.proteomatic.part', '')
			if File::exists?(@output[ls_Key])
				FileUtils::mv(@output[ls_Key], ls_RealName)
				lk_Files.push(File::basename(ls_RealName))
			end
		end
		
		# delete temporary files
		FileUtils::rm_rf(@mk_TempFiles)
		return lk_Files
	end
	
	
	def getFileInfo(as_Path, ab_Md5)
		lk_Info = Hash.new
		lk_Info['basename'] = File::basename(as_Path)
		lk_Info['directory'] = File::dirname(as_Path)
		lk_Info['size'] = File::size(as_Path)
		lk_Info['ctime'] = File::ctime(as_Path)
		lk_Info['mtime'] = File::mtime(as_Path)
		if ab_Md5
			lk_Digest = Digest::MD5.new()
			File.open(as_Path, 'rb') do |lk_File|
				while !lk_File.eof?
					ls_Chunk = lk_File.read(8 * 1024 * 1024) # read 8M
					lk_Digest << ls_Chunk
				end
			end
			lk_Info['md5'] = lk_Digest.hexdigest
		end
		
		return lk_Info
	end
	
	
	def submitRunToFileTracker()
		return unless @ms_FileTrackerHost
		print "Submitting run to file tracker at #{@ms_FileTrackerHost}:#{@mi_FileTrackerPort}... "
		
		begin
			lk_Info = Hash.new
			lk_Info['version'] = @ms_Version
			lk_Info['user'] = @ms_UserName
			lk_Info['host'] = @ms_HostName
			lk_Info['script_uri'] = @ms_ScriptName + '.rb'
			lk_Info['script_title'] = @ms_Title
			lk_Info['start_time'] = @mk_StartTime
			lk_Info['end_time'] = @mk_EndTime
			lk_Info['parameters'] = @mk_Parameters.humanReadableConfigurationHash()
			lk_Info['stdout'] = @ms_EavesdroppedOutput
			
			lk_Files = Array.new
			
			@input.each_key do |ls_Key|
				@input[ls_Key].each do |ls_Path|
					next unless File::exists?(ls_Path)
					lk_FileInfo = getFileInfo(ls_Path, !(@mk_DontMd5InputFiles.include?(ls_Key.to_s)))
					lk_FileInfo['input_file'] = true
					lk_Files.push(lk_FileInfo)
				end
			end
			@output.each_key do |ls_Key|
				ls_Path = @output[ls_Key].sub('.proteomatic.part', '')
				next unless File::exists?(ls_Path)
				lb_DoMd5 = !(@mk_DontMd5OutputFiles.include?(ls_Key.to_s))
				lb_DoMd5 = @mk_DontMd5OutputFiles.empty? if @ms_ScriptType == 'converter'
				lk_FileInfo = getFileInfo(ls_Path, lb_DoMd5)
				lk_FileInfo['input_file'] = false
				lk_Files.push(lk_FileInfo)
			end
			
			ls_RunInfo = {'run' => lk_Info, 'files' => lk_Files}.to_yaml
			
			lb_Success = doSubmitRunToFileTracker(ls_RunInfo)
			if lb_Success
				puts 'done.'
				# check whether there are unsent YAML reports
				lk_UnsentFiles = Dir[File::join(UNSENT_REPORTS_PATH, '*')]
				lk_UnsentFiles.each do |ls_Path|
					puts "Resending unsent run to filetracker..."
					ls_Info = File::read(ls_Path)
					if doSubmitRunToFileTracker(ls_Info)
						FileUtils::rm(ls_Path)	
					end
				end
				lk_UnsentFiles = Dir[File::join(UNSENT_REPORTS_PATH, '*')]
				FileUtils::rm_rf(UNSENT_REPORTS_PATH) if lk_UnsentFiles.empty?
			else
				# if the run could not be submitted, try to save the YAML report to a local file
				#puts "ATTENTION REPORT RESENDING *SAVE* DISABLED"
				FileUtils::mkpath(UNSENT_REPORTS_PATH)
				ls_Filename = tempFilename('unsent', UNSENT_REPORTS_PATH)
				File::open(ls_Filename, 'w') { |f| f.puts ls_RunInfo }
				puts
				puts "The filetracker report was saved to #{UNSENT_REPORTS_PATH} and will be resent the next time a Proteomatic script is run."
			end
		rescue StandardError => e
			puts "Oops, something went wrong while trying to submit the filetracker report."
		end
	end
	
	
	def doSubmitRunToFileTracker(as_RunInfo)
		lb_Success = false
		begin
			client = nil
			timeout(30) do
				client = TCPSocket.open(@ms_FileTrackerHost, @mi_FileTrackerPort)
				client.puts 'PROTEOMATIC_FILETRACKER_REPORT'
				client.puts 'VERSION 1'
				client.puts "LENGTH #{as_RunInfo.size}"
				
				client.puts as_RunInfo
				
				client.flush
				ls_Message = ''
				timeout(30) { ls_Message = client.readline }
				if ls_Message.strip == 'REPORT RECEIVED'
					timeout(30) { ls_Message = client.readline }
					if ls_Message.strip == 'REPORT COMMITTED'
						lb_Success = true
					end
				end
				client.close
			end
		rescue StandardError => e
			puts "\nUnable to connect to file tracker: #{e}"
		end
		return lb_Success
	end
	
	
	def fileDefiningOutputDirectory()
		return @ms_FileDefiningOutputDirectory
	end


	def findGroupForFile(as_Path)
		@mk_Input['ambiguousFormats'].each do |ls_Format|
			return nil if fileMatchesFormat(as_Path, ls_Format)
		end
		@mk_Input['groups'].each do |ls_Group, lk_Group|
			lk_Group['formats'].each do |ls_Format|
				return ls_Group, ls_Format if (fileMatchesFormat(as_Path, ls_Format))
			end
		end
		return nil
	end
	private :findGroupForFile

	def findFormatForFile(as_Path)
		@mk_Input['groups'].each do |ls_Group, lk_Group|
			lk_Group['formats'].each do |ls_Format|
				return ls_Format if (fileMatchesFormat(as_Path, ls_Format))
			end
		end
		return nil
	end
	private :findFormatForFile

	
	def param(as_Key)
    	return @mk_Parameters.value(as_Key)
	end
	
	def inputFiles(as_Group)
		return @mk_Input['files'][as_Group]
	end
	
	def tempFilename(as_Prefix = '', as_Directory = nil)
		as_Prefix = 'temp-' + as_Prefix
		as_Directory = @outputDirectory unless as_Directory
		lk_TempFile = Tempfile.new(as_Prefix, as_Directory)
		ls_TempFilename = lk_TempFile.path
		lk_TempFile.close!
		@mk_TempFiles.push(ls_TempFilename)
		return ls_TempFilename
	end

	def run()
		raise 'Internal error: run() must be implemented!'
		exit 1
	end
	
	def getConfigValue(as_Key)
		lk_Config = YAML::load_file(File::join('config', "#{@ms_ScriptName}.config.yaml"))
		return lk_Config[as_Key]
	end
	
	def runCommand(as_Command, ab_PrintStdOut = false)
		if (ab_PrintStdOut)
			system(as_Command)
		else
			ls_Output = %x{#{as_Command}}
		end
		unless $?.exitstatus == 0
			puts "Error: There was an error while executing #{as_Command.split(' ').first}."
			exit(1)
		end
		#puts ls_Output if ab_PrintStdOut			
	end
end
