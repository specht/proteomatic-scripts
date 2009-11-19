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

require 'include/ruby/proteomatic'
require 'include/ruby/externaltools'
require 'include/ruby/fasta'
require 'include/ruby/ext/fastercsv'
require 'include/ruby/formats'
require 'include/ruby/misc'
require 'yaml'
require 'fileutils'

class RunOmssa < ProteomaticScript

	def runOmssa(as_SpectrumFilename, as_DatabasePath, as_OutputDirectory, as_Format = 'csv')
		lk_OutFiles = Array.new
		
		lb_TestDtaExisted = File.exists?('test.dta')
		
		ls_OutFilename = tempFilename("omssa-out", as_OutputDirectory)
		lk_OutFiles.push(ls_OutFilename)
		
		ls_InputSwitch = '-fm'
		ls_InputSwitch = '-f' if fileMatchesFormat(as_SpectrumFilename, 'dta')

		ls_Command = "\"#{ExternalTools::binaryPath('omssa.omssacl')}\" -d \"#{as_DatabasePath}\" #{ls_InputSwitch} \"#{as_SpectrumFilename}\" -oc \"#{ls_OutFilename}\" -ni "
		ls_Command += @mk_Parameters.commandLineFor('omssa.omssacl')
		runCommand(ls_Command)
		
		# inject filename/id because when running a DTA, it seems to be missing
		if fileMatchesFormat(as_SpectrumFilename, 'dta')
			ls_FixedResult = ''
			File.open(ls_OutFilename, 'r') do |lk_File|
				ls_Header = lk_File.readline.strip
				ls_FixedResult += ls_Header + "\n"
				lk_HeaderMap = mapCsvHeader(ls_Header)
				lk_File.each_line do |ls_Line|
					ls_Line.strip!
					lk_Line = ls_Line.parse_csv()
					ls_Id = lk_Line[lk_HeaderMap['filenameid']]
					ls_Id ||= ''
					ls_Id.strip! unless ls_Id.empty?
					if (ls_Id.empty?)
						ls_Id = File::basename(as_SpectrumFilename)
						lk_Line[lk_HeaderMap['filenameid']] = ls_Id
						ls_FixedResult += FasterCSV.generate { |csv| csv << lk_Line }
					else
						ls_FixedResult += ls_Line + "\n"
					end
				end
			end
			File.open(ls_OutFilename, 'w') { |f| f.print(ls_FixedResult) }
		end	

		File::delete('test.dta') if File.exists?('test.dta') && !lb_TestDtaExisted
		
		return lk_OutFiles
	end


	def run()
		@ms_TempPath = tempFilename('run-omssa')
		FileUtils::mkpath(@ms_TempPath)
		# use the temp path for the BLAST database as well
		# BUT: if there are spaces in the path, find something else
		ls_DatabaseTempPath = @ms_TempPath
		if ls_DatabaseTempPath.include?(' ')
			@input[:databases].each do |ls_DatabasePath|
				ls_DatabaseTempPath = tempFilename('run-omssa', File::dirname(ls_DatabasePath))
				break unless ls_DatabaseTempPath.include?(' ')
			end
		end
		ls_DatabaseTempPath = Dir::tmpdir if (ls_DatabaseTempPath.include?(' '))
		ls_DatabaseTempPath = 'c:/' if (ls_DatabaseTempPath.include?(' '))
		if (ls_DatabaseTempPath.include?(' '))
			puts 'Sorry, but Run OMSSA is unable to continue.'
			puts 'For the conversion of the FASTA database into the BLAST format, formatdb is used ' +
			'which requires a path without spaces. In order to solve this problem, please move the ' +
			'FASTA database file to a location without spaces in the path.'
			exit 1
		else
			FileUtils::mkpath(ls_DatabaseTempPath)
		end
		
		puts 'Merging databases...' unless @input[:databases].size == 1
		ls_DatabasePath= tempFilename('merged-database', ls_DatabaseTempPath);
		File::open(ls_DatabasePath, 'w') do |lk_OutFile|
			@input[:databases].each do |ls_Path|
				File::open(ls_Path, 'r') { |lk_InFile| lk_OutFile.puts(lk_InFile.read) }
			end
		end
		
		puts 'Converting database to BLAST format...'
		createBlastDatabase(ls_DatabasePath)
		
		# check if there are spectra files that are not dta or mgf
		lk_PreparedSpectraFiles = Array.new
		lk_XmlFiles = Array.new
		@input[:spectra].each do |ls_Path|
			if ['dta', 'mgf'].include?(@inputFormat[ls_Path])
				# it's DTA or MGF, give that directly to OMSSA
				lk_PreparedSpectraFiles.push(ls_Path)
			else
				# it's something else, convert it first
				lk_XmlFiles.push("\"" + ls_Path + "\"") 
			end
		end
		
		unless (lk_XmlFiles.empty?)
			# convert spectra to MGF
			puts 'Converting XML spectra to MGF format...'
			ls_Command = "\"#{ExternalTools::binaryPath('ptb.xml2mgf')}\" -b #{@param[:batchSize]} -o \"#{@ms_TempPath}/mgf-in\" -rt \"#{@ms_TempPath}/rt.yaml\" #{lk_XmlFiles.join(' ')}"
			runCommand(ls_Command)
			
			lk_PreparedSpectraFiles = lk_PreparedSpectraFiles + Dir[@ms_TempPath + '/mgf-in*']
		end
		
		ls_RtPath = File::join(@ms_TempPath, 'rt.yaml')
		lk_RetentionTimes = Hash.new
		lk_RetentionTimes = YAML::load_file(ls_RtPath) if File::exists?(ls_RtPath)
		
		# run OMSSA on each spectrum file
		lk_OutFiles = Array.new
		li_Counter = 0
		lk_PreparedSpectraFiles.each do |ls_Path|
			print "\rRunning OMSSA: #{li_Counter * 100 / lk_PreparedSpectraFiles.size}% done."
			lk_OutFiles += runOmssa(ls_Path, ls_DatabasePath, @ms_TempPath, 'csv')
			li_Counter += 1
		end
		puts "\rRunning OMSSA: 100% done."
		
		# merge results
		ls_TempResultPath = File::join(@ms_TempPath, 'temp-results.csv')
		print "Merging OMSSA results..."
		mergeCsvFiles(lk_OutFiles, ls_TempResultPath)
		puts 'done.'
		
		unless (lk_RetentionTimes.empty?)
			print "Injecting retention times into OMSSA results..."
			File.open(@output[:resultFile], 'w') do |lk_Out|
				File.open(ls_TempResultPath, 'r') do |lk_File|
					ls_Header = lk_File.readline.strip
					lk_Out.puts "#{ls_Header}, retentionTime"
					lk_HeaderMap = mapCsvHeader(ls_Header)
					lk_File.each_line do |ls_Line|
						ls_Line.strip!
						lk_Line = ls_Line.parse_csv()
						ls_Band = lk_Line[lk_HeaderMap['filenameid']]
						lk_Band = ls_Band.split('.')
						ls_Key = "#{lk_Band.slice(0, lk_Band.size - 2).join('.')}"
						ld_RetentionTime = lk_RetentionTimes[ls_Key]
						lk_Out.puts "#{ls_Line},#{ld_RetentionTime}"
					end
				end
			end
			puts "done."
		else
			FileUtils::cp(ls_TempResultPath, @output[:resultFile])
		end
	end
end

lk_Object = RunOmssa.new
