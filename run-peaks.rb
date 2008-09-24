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
require 'include/spectrum'
require 'yaml'
require 'fileutils'

class RunPeaks < ProteomaticScript
	def run()
		
		lk_SpectrumFiles = @input[:spectra]
		
		ls_PeaksConfig = ''
		ls_PeaksConfig += "<combine_result_files>1</combine_result_files>\n"
		ls_PeaksConfig += "<delete_temp>1</delete_temp>\n"
		ls_PeaksConfig += "<max_charge>2</max_charge>\n"
		ls_PeaksConfig += "<enzyme>Trypsin without PTMs</enzyme>\n"
		ls_PeaksConfig += "<frag_tol>1</frag_tol>\n"
		ls_PeaksConfig += "<instrument>-i</instrument>\n"
		ls_PeaksConfig += "<output_num>10</output_num>\n"
		ls_PeaksConfig += "<par_tol>1.5</par_tol>\n"
		
		ls_TempInDir = tempFilename('peaks-in')
		FileUtils::mkdir(ls_TempInDir)
		FileUtils::mkpath(File::join(ls_TempInDir, 'out'))
		ls_MgfFile = File::join(ls_TempInDir, 'in.mgf')
		File.open(ls_MgfFile, 'w') do |lk_MgfFile|
			lk_SpectrumFiles.each do |ls_SpectrumFilename|
				lk_SpectrumProc = Proc.new { |ls_Contents| lk_MgfFile.write(ls_Contents) }
				MgfIterator.new(ls_SpectrumFilename, lk_SpectrumProc, :levels => 2).run
			end
		end
		ls_ParamFile = tempFilename('peaks-config') + '.xml'
		File.open(ls_ParamFile, 'w') do |lk_File|
			lk_File.write(ls_PeaksConfig)
		end
		
		lf_PrecursorTolerance = @param[:precursorIonTolerance]
		lf_ProductTolerance = @param[:productIonTolerance]
		ls_Parameters = "-xfi #{ls_TempInDir} #{File::join(ls_TempInDir, 'out')} \"Trypsin without PTMs\" #{lf_PrecursorTolerance} #{lf_ProductTolerance} 10 1"
        ls_Command = "java -Xmx512M -jar #{getConfigValue('peaksBatchJar')} " + ls_Parameters
        print 'Running PEAKS...'
        system(ls_Command)
        File::rename(File::join(ls_TempInDir, 'out', 'in.fas'), @output[:fasFile]) if @output[:fasFile]
        File::rename(File::join(ls_TempInDir, 'out', 'in.ann'), @output[:annFile]) if @output[:annFile]
        FileUtils::rm_rf(ls_TempInDir)
        FileUtils::rm(ls_ParamFile) 
        puts 'done.'
	end
end

lk_Object = RunPeaks.new
