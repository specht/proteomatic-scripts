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
require 'yaml'
require 'fileutils'

class RunPeaks < ProteomaticScript
	def run()
		ls_PeaksConfig = ''
		ls_PeaksConfig += "<combine_result_files>1</combine_result_files>\n"
		ls_PeaksConfig += "<delete_temp>1</delete_temp>\n"
		ls_PeaksConfig += "<max_charge>2</max_charge>\n"
		ls_PeaksConfig += "<enzyme>Trypsin without PTMs</enzyme>\n"
		ls_PeaksConfig += "<frag_tol>1</frag_tol>\n"
		ls_PeaksConfig += "<instrument>-i</instrument>\n"
		ls_PeaksConfig += "<output_num>10</output_num>\n"
		ls_PeaksConfig += "<par_tol>1.5</par_tol>\n"
		
		ls_TempPath = tempFilename('peaks')
		ls_TempInPath = File::join(ls_TempPath, 'in')
		ls_TempOutPath = File::join(ls_TempPath, 'out')
		FileUtils::mkpath(ls_TempInPath)
		FileUtils::mkpath(ls_TempOutPath)
		
		# check if there are spectra files that are not dta or mgf
		lk_PreparedSpectraFiles = Array.new
		lk_XmlFiles = Array.new
		@input[:spectra].each do |ls_Path|
			if ['dta', 'mgf'].include?(@inputFormat[ls_Path])
				# it's DTA or MGF, give that directly to PEAKS
				lk_PreparedSpectraFiles.push(ls_Path)
				File::cp(ls_Path, ls_TempInPath)
			else
				# it's something else, convert it first
				lk_XmlFiles.push("\"" + ls_Path + "\"") 
			end
		end
		
		unless (lk_XmlFiles.empty?)
			# convert spectra to MGF
			puts 'Converting XML spectra to MGF format...'
			puts 'There was an error while executing xml2mgf.' unless system("\"#{ExternalTools::binaryPath('simquant.xml2mgf')}\" -o \"#{ls_TempInPath}\" #{lk_XmlFiles.join(' ')}");
		end
		
		ls_ParamFile = File::join(ls_TempPath, 'peaks-config.xml')
		File.open(ls_ParamFile, 'w') do |lk_File|
			lk_File.write(ls_PeaksConfig)
		end
		
		lf_PrecursorTolerance = @param[:precursorIonTolerance]
		lf_ProductTolerance = @param[:productIonTolerance]
		ls_Parameters = "-xfi #{ls_TempInPath} #{ls_TempOutPath} \"Trypsin without PTMs\" #{lf_PrecursorTolerance} #{lf_ProductTolerance} 10 1"
		ls_OldPath = Dir::pwd()
		Dir::chdir(ls_TempPath)
        ls_Command = "java -Xmx512M -jar #{getConfigValue('peaksBatchJar')} " + ls_Parameters
        print 'Running PEAKS...'
        puts 'There was an error while executing PEAKS.' unless system(ls_Command)
		Dir::chdir(ls_OldPath)
        File::rename(File::join(ls_TempOutPath, 'in.fas'), @output[:fasFile]) if @output[:fasFile]
        File::rename(File::join(ls_TempOutPath, 'in.ann'), @output[:annFile]) if @output[:annFile]
        FileUtils::rm_rf(ls_TempPath)
        puts 'done.'
	end
end

lk_Object = RunPeaks.new
