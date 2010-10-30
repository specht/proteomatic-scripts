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

require './include/ruby/proteomatic'
require './include/ruby/evaluate-omssa-helper'
require './include/ruby/ext/fastercsv'
require './include/ruby/misc'
require 'set'
require 'yaml'

class FilterPsmByThreshold < ProteomaticScript
    def run()
        # first check whether all headers are equal, because in the end they will be merged
        ls_Header = nil
        lk_HeaderMap = nil
        @input[:omssaResults].each do |ls_Path|
            File.open(ls_Path, 'r') do |lk_In|
                # skip header
                ls_Header = lk_In.readline.strip
                lk_ThisHeaderMap = mapCsvHeader(ls_Header)
                if (lk_HeaderMap)
                    if (lk_HeaderMap != lk_ThisHeaderMap)
                        puts "Error: The header lines of all input files are not identical (#{ls_Path} is different, for example)."
                        exit 1
                    end
                end
                lk_HeaderMap = lk_ThisHeaderMap
            end
        end

        lk_Result = Hash.new
        
        # If we stumble across a PSM with __td__target_ or __td__decoy_ in front, obviously the results
        # are to be treated with a fixed threshold because the FPR approach didn't work out
        # well, because the result list was too small. In that case, we only give out a 
        # warning once and just strip the leading __td__target_ or __td__decoy_
        lb_GaveWarningAboutTargetDecoy = false
        
        ld_ScoreThreshold = @param[:scoreThreshold].to_f
        puts "Removing all PSM with a score of #{@param[:scoreThresholdType] == 'min' ? 'less' : 'more'} than #{ld_ScoreThreshold}."
        
        if @output[:croppedPsm]
            File.open(@output[:croppedPsm], 'w') do |lk_Out|
                ls_Header += ', scoreThresholdType, scoreThreshold'
                lk_Out.puts(ls_Header)
                @input[:omssaResults].each do |ls_Path|
                    File.open(ls_Path, 'r') do |lk_In|
                        lk_In.readline
                        lk_In.each do |ls_Line|
                            lk_Line = ls_Line.parse_csv()
                            lf_E = BigDecimal.new(lk_Line[lk_HeaderMap['evalue']])
                            ls_DefLine = lk_Line[lk_HeaderMap['defline']]
                            if (ls_DefLine.index('__td__target_') == 0) || (ls_DefLine.index('__td__decoy_') == 0)
                                unless lb_GaveWarningAboutTargetDecoy
                                    puts "Warning: The PSM lists you provided contain target/decoy results, which usually should be evaluated with a FPR filter. However, if the FPR approach didn't work out well because of to few results, you can still use a fixed threshold."
                                    lb_GaveWarningAboutTargetDecoy = true
                                end
                                next if (ls_DefLine.index('__td__decoy_')) == 0
                                ls_DefLine.delete!('__td__target_') 
                            end
                            # is the score too bad? skip it!
                            if (@param[:scoreThresholdType] == 'min')
                                next if lf_E < ld_ScoreThreshold
                            elsif (@param[:scoreThresholdType] == 'max')
                                next if lf_E > ld_ScoreThreshold
                            end
                            
                            lk_Out.print ls_Line.sub('__td__target_', '').strip
                            lk_Out.print ", #{@param[:scoreThresholdType]}, #{ld_ScoreThreshold}"
                            lk_Out.puts
                        end
                    end
                end
            end
        end
    end
end

lk_Object = FilterPsmByThreshold.new
