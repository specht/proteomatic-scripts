# Copyright (c) 2010 Michael Specht
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

class ApplyProteinGroups < ProteomaticScript
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
        
        proteinGroupsInfo = YAML::load_file(@input[:proteinGroups].first)
        
        proteinGroups = Array.new
        proteinGroupsForProtein = Hash.new
        
        proteinGroupsInfo['proteinGroups'].each do |list|
            combinedName = "__group__" + list.join("\01")
            combinedName = list.first if list.size == 1
            proteinGroups << combinedName
            list.each do |protein|
                proteinGroupsForProtein[protein] ||= Array.new
                proteinGroupsForProtein[protein] << (proteinGroups.size - 1)
            end
        end
        
        puts "Got #{proteinGroupsForProtein.size} proteins in #{proteinGroups.size} protein groups."

        lk_Result = Hash.new
        
        if @output[:results]
            print "Replacing proteins with protein groups..."
            File.open(@output[:results], 'w') do |lk_Out|
                lk_Out.puts(ls_Header)
                @input[:omssaResults].each do |ls_Path|
                    File.open(ls_Path, 'r') do |lk_In|
                        # skip header, we already made sure it's always the same
                        # and we wrote it already
                        lk_In.readline
                        lk_In.each_line do |line|
                            lineArray = line.parse_csv()
                            protein = lineArray[lk_HeaderMap['defline']]
                            if proteinGroupsForProtein.include?(protein)
                                proteinGroupsForProtein[protein].each do |group|
                                    lineArray[lk_HeaderMap['defline']] = proteinGroups[group]
                                end
                            end
                            lk_Out.puts lineArray.to_csv()
                        end
                    end
                end
            end
            puts "done."
        end
    end
end

lk_Object = ApplyProteinGroups.new
