#! /usr/bin/env ruby
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

require './include/ruby/proteomatic'
require './include/ruby/misc'
require 'yaml'
require 'fileutils'


class RunPeaks < ProteomaticScript
    def run()
        ls_PeaksConfig = readData('config').strip
        
        ls_VariableMods = ''
        if @param[:variableModifications] && !@param[:variableModifications].empty?
            ls_VariableMods = "<varied_modi>\n"
            ls_VariableMods += @param[:variableModifications].split(',').collect { |x| "<modi>#{x}</modi>\n" }.join('')
            ls_VariableMods += "</varied_modi>\n"
        end
        
        ls_PeaksConfig.sub!('#{VARIABLE_MODS}', ls_VariableMods)
        ls_PeaksConfig.sub!('#{ENZYME}', readData('enzyme_' + @param[:enzyme]).strip)
        ls_PeaksConfig.sub!('#{PRECURSOR_TOLERANCE}', @param[:precursorIonTolerance].to_s)
        ls_PeaksConfig.sub!('#{PRODUCT_TOLERANCE}', @param[:productIonTolerance].to_s)
        
        # no empty lines allowed in PEAKS config
        ls_PeaksConfig.sub!("\n\n", "\n")
        
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
        ls_Parameters = "-xfi \"#{ls_TempInPath}\" \"#{ls_TempOutPath}\" \"#{ls_ParamFile}\" \"Proteomatic resptm\" #{lf_PrecursorTolerance} #{lf_ProductTolerance} 10 2"
        ls_Command = "java -Xmx512M -jar #{getConfigValue('peaksBatchJar')} " + ls_Parameters
        print 'Running PEAKS...'
        ls_OldPath = Dir::pwd()
        Dir::chdir(ls_TempPath)
        runCommand(ls_Command)
        
        Dir::chdir(ls_OldPath)
        if @output[:fasFile]
            File::open(@output[:fasFile], 'w') do |f|
                Dir[File::join(ls_TempOutPath, '*.fas')].each do |path|
                    contents = File::read(path)
                    f.puts contents
                end
            end
        end
        FileUtils::rm_rf(ls_TempPath)
        puts 'done.'
    end
end

script = RunPeaks.new

__END__

__CONFIG__
<?xml version="1.0" encoding="UTF-8"?>
<PEAKS_Properties>
<combine_result_files>1</combine_result_files>
<delete_temp>1</delete_temp>
<max_charge>2</max_charge>
<enzyme>Trypsin with Phosphorylation</enzyme>
<frag_tol>#{PRODUCT_TOLERANCE}</frag_tol>
<instrument>-i</instrument>
<output_num>10</output_num>
<par_tol>#{PRECURSOR_TOLERANCE}</par_tol>
<user_residue_list version="1.0">
<res_ptm_set name="Proteomatic resptm">
#{ENZYME}
#{VARIABLE_MODS}
</res_ptm_set>
</user_residue_list>
</PEAKS_Properties>
__CONFIG__

__ENZYME_TRYPSIN__
<enzyme>Trypsin</enzyme>
<res_n_term>ARNDCEQGHLKMFSTWYV</res_n_term>
<res_middle>ARNDCEQGHLKMFPSTWYV</res_middle>
<res_c_term>RK</res_c_term>
__ENZYME_TRYPSIN__

__ENZYME_LYSC__
<enzyme>Trypsin</enzyme>
<res_n_term>ARNDCEQGHLKMFPSTWYV</res_n_term>
<res_middle>ARNDCEQGHLKMFPSTWYV</res_middle>
<res_c_term>K</res_c_term>
__ENZYME_LYSC__

__ENZYME_CHYMOTRYPSIN__
<enzyme>Trypsin</enzyme>
<res_n_term>ARNDCEQGHLKMFSTWYV</res_n_term>
<res_middle>ARNDCEQGHLKMFPSTWYV</res_middle>
<res_c_term>FYWML</res_c_term>
__ENZYME_CHYMOTRYPSIN__

__ENZYME_PEPSINC__
<enzyme>Pepsin C-term</enzyme>
<res_n_term>ARNDCEQGHLKMFPSTWYV</res_n_term>
<res_middle>ARNDCEQGHLKMFPSTWYV</res_middle>
<res_c_term>FLWY</res_c_term>
__ENZYME_PEPSINC__

__ENZYME_PEPSINN__
<enzyme>Pepsin N-term</enzyme>
<res_n_term>FLWY</res_n_term>
<res_middle>ARNDCEQGHLKMFPSTWYV</res_middle>
<res_c_term>ARNDCEQGHLKMFPSTWYV</res_c_term>
__ENZYME_PEPSINN__
