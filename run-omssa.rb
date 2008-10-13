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

	def runOmssa(as_SpectrumFilename, ak_Databases, as_OutputDirectory, as_Format = 'csv')
		lk_TargetDecoyFilenames = Array.new()
		ak_Databases.each { |ls_Path| lk_TargetDecoyFilenames.push(getTargetDecoyFilename(ls_Path)) }
		lk_OutFiles = Array.new
		
		lb_TestDtaExisted = File.exists?('test.dta')
		
		lk_TargetDecoyFilenames.each do |ls_TargetDecoyPath|
			ls_OutFilename = tempFilename("omssa-out", as_OutputDirectory)
			lk_OutFiles.push(ls_OutFilename)
			
			ls_InputSwitch = '-fm'
			ls_InputSwitch = '-f' if fileMatchesFormat(as_SpectrumFilename, 'dta')

			ls_Command = "\"#{ExternalTools::binaryPath('omssa.omssacl')}\" -d \"#{ls_TargetDecoyPath}\" #{ls_InputSwitch} \"#{as_SpectrumFilename}\" -oc \"#{ls_OutFilename}\" -ni "
			ls_Command += @mk_Parameters.commandLineFor('omssa.omssacl')
			runCommand(ls_Command)1
		end

		File::delete('test.dta') if File.exists?('test.dta') && !lb_TestDtaExisted
		
		return lk_OutFiles
	end


	def run()
		# merge all input databases into one database
		lb_MergedDatabase = false
		lk_Databases = Array.new
		if @input[:databases].size == 1
			lk_Databases = @input[:databases]
		else
			puts 'Merging databases...'
			lb_MergedDatabase = true
			ls_MergedDatabase = tempFilename('merged-database');
			File::open(ls_MergedDatabase, 'w') do |lk_OutFile|
				@input[:databases].each do |ls_Path|
					File::open(ls_Path, 'r') do |lk_InFile|
						ls_Contents = lk_InFile.read
						ls_Contents += "\n" unless ls_Contents[-1] == "\n"
						lk_OutFile.write(ls_Contents)
					end
				end
			end
			lk_Databases = [ls_MergedDatabase]
		end
		
		puts 'Creating target-decoy database and converting to BLAST format...'
		# ensure that all databases are target-decoy and in BLAST format
		lk_ToBeDeleted = Array.new
		lk_Databases.each do |ls_Path|
			createTargetDecoyDatabase(ls_Path)
			createBlastDatabase(getTargetDecoyFilename(ls_Path))
			if (lb_MergedDatabase)
				lk_ToBeDeleted.push(getTargetDecoyFilename(ls_Path))
				lk_ToBeDeleted.push(getTargetDecoyFilename(ls_Path) + '.phr')
				lk_ToBeDeleted.push(getTargetDecoyFilename(ls_Path) + '.psq')
				lk_ToBeDeleted.push(getTargetDecoyFilename(ls_Path) + '.pin')
			end
		end
		
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
		
		ls_TempPath = tempFilename('run-omssa')
		FileUtils::mkpath(ls_TempPath)
		unless (lk_XmlFiles.empty?)
			# convert spectra to MGF
			puts 'Converting XML spectra to MGF format...'
			ls_Command = "\"#{ExternalTools::binaryPath('simquant.xml2mgf')}\" -b #{@param[:batchSize]} -o \"#{ls_TempPath}/mgf-in\" #{lk_XmlFiles.join(' ')}"
			runCommand(ls_Command)
			
			lk_PreparedSpectraFiles = lk_PreparedSpectraFiles + Dir[ls_TempPath + '/mgf-in*']
		end
		
		# run OMSSA on each spectrum file
		lk_OutFiles = Array.new
		li_Counter = 0
		lk_PreparedSpectraFiles.each do |ls_Path|
			print "\rRunning OMSSA: #{li_Counter * 100 / lk_PreparedSpectraFiles.size}% done."
			lk_OutFiles += runOmssa(ls_Path, lk_Databases, ls_TempPath, 'csv')
			li_Counter += 1
		end
		puts "\rRunning OMSSA: 100% done."
		
		# merge results
		print "Merging OMSSA results..."
		mergeCsvFiles(lk_OutFiles, @output[:resultFile])
		
		FileUtils.rm_f(lk_ToBeDeleted);
		puts "done."
	end
end

lk_Object = RunOmssa.new
