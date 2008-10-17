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

require 'include/proteomatic'
require 'include/externaltools'
require 'include/fasta'
require 'include/formats'
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

		File::delete('test.dta') if File.exists?('test.dta') && !lb_TestDtaExisted
		
		return lk_OutFiles
	end


	def run()
		@ms_TempPath = tempFilename('run-omssa')
		FileUtils::mkpath(@ms_TempPath)
		
		# if target-decoy if switched off and we have multiple databases,
		# merge all of them into one database
		ls_DatabasePath = nil
		if !@param[:doTargetDecoy]
			# no target decoy!
			puts 'Merging databases...' unless @input[:databases].size == 1
			ls_DatabasePath= tempFilename('merged-database', @ms_TempPath);
			File::open(ls_DatabasePath, 'w') do |lk_OutFile|
				@input[:databases].each do |ls_Path|
					File::open(ls_Path, 'r') { |lk_InFile| lk_OutFile.puts(lk_InFile.read) }
				end
			end
		else
			# yay, make it target decoy!
			puts "Creating target-decoy database..."
			ls_DatabasePath= tempFilename('target-decoy-database', @ms_TempPath);
			ls_Command = "#{ExternalTools::binaryPath('simquant.decoyfasta')} --output #{ls_DatabasePath} --method #{@param[:targetDecoyMethod]} --keepStart #{@param[:targetDecoyKeepStart]} --keepEnd #{@param[:targetDecoyKeepEnd]} #{@input[:databases].join(' ')}"
			runCommand(ls_Command, true)
		end
		
		puts 'Converting database to BLAST format...'
		puts ls_DatabasePath
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
			ls_Command = "\"#{ExternalTools::binaryPath('simquant.xml2mgf')}\" -b #{@param[:batchSize]} -o \"#{@ms_TempPath}/mgf-in\" #{lk_XmlFiles.join(' ')}"
			runCommand(ls_Command)
			
			lk_PreparedSpectraFiles = lk_PreparedSpectraFiles + Dir[@ms_TempPath + '/mgf-in*']
		end
		
		# run OMSSA on each spectrum file
		lk_OutFiles = Array.new
		li_Counter = 0
		lk_PreparedSpectraFiles.each do |ls_Path|
			print "\rRunning OMSSA: #{li_Counter * 100 / lk_PreparedSpectraFiles.size}% done."
			lk_OutFiles += runOmssa(ls_Path, ls_DatabasePath, @ms_TempPath, 'csv')
			li_Counter += 1
		end
		puts "\rRunning OMSSA: 100% done."
		
		exit 1
		
		# merge results
		print "Merging OMSSA results..."
		mergeCsvFiles(lk_OutFiles, @output[:resultFile])
		
		puts "done."
	end
end

lk_Object = RunOmssa.new
