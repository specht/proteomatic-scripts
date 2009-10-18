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

# Run Peaks (a Proteomatic script)

require 'include/proteomatic'
require 'yaml'
require 'fileutils'


class RunPeaks < ProteomaticScript
	def run()
		ls_PeaksConfig = DATA.read
		
		ls_VariableMods = ''
		if @param[:variableModifications] && !@param[:variableModifications].empty?
			ls_VariableMods = "<varied_modi>\n"
			ls_VariableMods += @param[:variableModifications].split(',').collect { |x| "<modi>#{x}</modi>\n" }.join('')
			ls_VariableMods += "</varied_modi>\n"
		end
		
		ls_PeaksConfig.sub!('#{VARIABLE_MODS}', ls_VariableMods)
		
		puts ls_PeaksConfig
		
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
				FileUtils::cp(ls_Path, ls_TempInPath)
			else
				# it's something else, convert it first
				lk_XmlFiles.push("\"" + ls_Path + "\"") 
			end
		end
		
		unless (lk_XmlFiles.empty?)
			# convert spectra to MGF
			puts 'Converting XML spectra to MGF format...'
			ls_Command = "\"#{ExternalTools::binaryPath('ptb.xml2mgf')}\" -o \"#{File::join(ls_TempInPath, 'xml2mgf-out.mgf')}\" #{lk_XmlFiles.join(' ')}"
			runCommand(ls_Command)
		end
		
		ls_ParamFile = File::join(ls_TempPath, 'peaks-config.xml')
		File.open(ls_ParamFile, 'w') do |lk_File|
			lk_File.write(ls_PeaksConfig)
		end
		
		lf_PrecursorTolerance = @param[:precursorIonTolerance]
		lf_ProductTolerance = @param[:productIonTolerance]
		ls_Parameters = "-xfi #{ls_TempInPath} #{ls_TempOutPath} #{ls_ParamFile} \"Proteomatic resptm\" #{lf_PrecursorTolerance} #{lf_ProductTolerance} 10 2"
		ls_Command = "java -Xmx512M -jar #{getConfigValue('peaksBatchJar')} " + ls_Parameters
		print 'Running PEAKS...'
		ls_OldPath = Dir::pwd()
		Dir::chdir(ls_TempPath)
		runCommand(ls_Command)
		
		Dir::chdir(ls_OldPath)
        File::rename(File::join(ls_TempOutPath, 'xml2mgf-out.fas'), @output[:fasFile]) if @output[:fasFile]
        File::rename(File::join(ls_TempOutPath, 'xml2mgf-out.ann'), @output[:annFile]) if @output[:annFile]
        FileUtils::rm_rf(ls_TempPath)
        puts 'done.'
	end
end

lk_Object = RunPeaks.new

__END__
<?xml version="1.0" encoding="UTF-8"?>
<PEAKS_Properties>
<combine_result_files>1</combine_result_files>
<delete_temp>1</delete_temp>
<max_charge>2</max_charge>
<enzyme>Trypsin with Phosphorylation</enzyme>
<frag_tol>1</frag_tol>
<instrument>-i</instrument>
<output_num>10</output_num>
<par_tol>1.5</par_tol>
<user_residue_list version="1.0">
<res_ptm_set name="Proteomatic resptm">
<enzyme>Trypsin</enzyme>
<res_n_term>ARNDCEQGHLKMFSTWYV</res_n_term>
<res_middle>ARNDCEQGHLKMFPSTWYV</res_middle>
<res_c_term>RK</res_c_term>
#{VARIABLE_MODS}
</res_ptm_set>
</user_residue_list>
</PEAKS_Properties>
