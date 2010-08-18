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
require 'include/ruby/evaluate-omssa-helper'
require 'include/ruby/ext/fastercsv'
require 'include/ruby/misc'
require 'set'
require 'yaml'


class RequireMs2Event < ProteomaticScript
    def run()
        # test whether QE CSV headers are all the same
        ls_AllHeader = nil
        lk_AllHeader = nil
        @input[:quantitationEvents].each do |ls_InPath|
            File::open(ls_InPath, 'r') do |lk_In|
                ls_Header = lk_In.readline
                lk_Header = Set.new(mapCsvHeader(ls_Header).keys())
                ls_AllHeader ||= ls_Header
                lk_AllHeader = lk_Header
                if lk_Header != lk_AllHeader
                    puts "Error: The CSV header was not consistent throughout all quantitation event input files. The offending header line was #{ls_Header}."
                    exit 1
                end
            end
        end

        # load all PSM and record every unmodified identification event
        # lk_Ms2Events[band][peptide] = list of retention times (unsorted)
        lk_Ms2Events = Hash.new
        @input[:psmList].each do |ls_PsmPath|
            ls_RunName = File::basename(ls_PsmPath).sub('.csv', '')
            print "Loading #{File::basename(ls_PsmPath)}..."
            lk_Results = loadPsm(ls_PsmPath, :silent => true)
            lk_Results[:peptideHash].each_pair do |ls_Peptide, lk_Peptide|
                lk_Peptide[:scans].each do |ls_Scan|
                    if lk_Results[:scanHash][ls_Scan][:retentionTime]
                        lf_RetentionTime = lk_Results[:scanHash][ls_Scan][:retentionTime]
                        ls_Band = ls_Scan.split('.').first
                        lk_Ms2Events[ls_Band] ||= Hash.new
                        lk_Ms2Events[ls_Band][ls_Peptide] ||= Array.new
                        lk_Ms2Events[ls_Band][ls_Peptide].push(lf_RetentionTime)
                    end
                end
            end
            puts ''
        end
        
        if @output[:results]
            File::open(@output[:results], 'w') do |lk_Out|
                print 'Writing filtered results...'
                li_InCount = 0
                li_OutCount = 0
                lk_Out.puts ls_AllHeader
                @input[:quantitationEvents].each do |ls_InPath|
                    File::open(ls_InPath, 'r') do |lk_In|
                        ls_Header = lk_In.readline
                        lk_Header = mapCsvHeader(ls_Header)
                        lk_In.each_line do |ls_Line|
                            li_InCount += 1
                            lk_Line = ls_Line.parse_csv()
                            ls_Band = lk_Line[lk_Header['filename']].split('.').first
                            ls_Peptide = lk_Line[lk_Header['peptide']]
                            lf_RetentionTime = lk_Line[lk_Header['retentiontime']].to_f
                            if lk_Ms2Events[ls_Band]
                                if lk_Ms2Events[ls_Band][ls_Peptide]
                                    lf_Minimum = nil
                                    lk_Ms2Events[ls_Band][ls_Peptide].each do |lf_Ms2Time|
                                        lf_Difference = (lf_Ms2Time - lf_RetentionTime).abs()
                                        lf_Minimum ||= lf_Difference
                                        lf_Minimum = lf_Difference if (lf_Difference < lf_Minimum)
                                    end
                                    if (lf_Minimum <= @param[:maxTimeDifference])
                                        lk_Out.puts ls_Line
                                         li_OutCount += 1
                                     end
                                end
                            end
                        end
                    end
                end
                puts
                puts "Discarded #{li_InCount - li_OutCount} of #{li_InCount} hits (#{sprintf('%1.1f', (li_InCount - li_OutCount).to_f / li_InCount.to_f * 100.0)}%)."
            end
        end
    end
end

lk_Object = RequireMs2Event.new
