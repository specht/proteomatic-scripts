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


class CompareQuantitationRatios < ProteomaticScript
    def run()
        scope = @param[:scope]
        columnCount = Hash.new
        columnCount['peptide'] = 0
        columnCount['protein'] = 0
        @input[:ratios].each do |path|
            File::open(path, 'r') do |f|
                header = mapCsvHeader(f.readline)
                columnCount['peptide'] += 1 if header.include?('peptide')
                columnCount['protein'] += 1 if header.include?('protein')
            end
        end
        if (scope == 'automatic')
            if columnCount['protein'] == @input[:ratios].size
                scope = 'protein'
            elsif columnCount['peptide'] == @input[:ratios].size
                scope = 'peptide'
            else
                puts "Error: Unable to automatically determine comparison scope."
                exit 1
            end
            puts "Auto-selecting #{scope} scope for comparison."
        end
        unless columnCount[scope] == @input[:ratios].size
            puts "Error: There is no '#{scope}' column in every input file."
            exit 1
        end
        itemHash = Hash.new
        basenames = @input[:ratios].collect { |x| File::basename(x) }
        if @param[:useShortColumnHeaders]
            inputKeys = mergeFilenames(basenames, true)
            inputKeys ||= basenames
        else
            inputKeys = basenames.dup
        end
        @input[:ratios].each_with_index do |path, inputFileIndex|
            File::open(path, 'r') do |f|
                header = mapCsvHeader(f.readline)
                f.each_line do |line|
                    lineArray = line.parse_csv()
                    item = lineArray[header[scope]]
                    itemHash[item] ||= Hash.new
                    itemHash[item][inputKeys[inputFileIndex]] = Hash.new
                    header.each_pair do |key, index|
                        itemHash[item][inputKeys[inputFileIndex]][key.intern] = lineArray[index]
                    end
                end
            end
        end
        outLines = 0
        if @output[:results]
            File::open(@output[:results], 'w') do |out|
                prettyColumn = {
                    'ratiomean' => 'Ratio Mean',
                    'ratiosd' => 'Ratio SD',
                    'pbccount' => 'PBC count',
                    'scancount' => 'Scan count'
                }
                columns = ['ratiomean', 'ratiosd', 'pbccount', 'scancount'].select { |x| @param[x.intern] }
                out.print scope.capitalize
                inputKeys.each do |inputKey|
                    columns.each do |c|
                        out.print ",\"#{inputKey} #{prettyColumn[c]}\""
                    end
                end
                out.puts
                itemHash.each_pair do |item, entry|
                    next unless (entry.size == @input[:ratios].size) || @param[:keepOutliers]
                    out.print "\"#{item}\""
                    inputKeys.each do |inputKey|
                        if entry.include?(inputKey)
                            columns.each do |x|
                                out.print ",#{entry[inputKey][x.intern ]}"
                            end
                        else
                            columns.each { |x| out.print "," }
                        end
                    end
                    out.puts
                    outLines += 1
                end
            end
        end
        puts "Wrote #{outLines} output lines."
    end
end


lk_Object = CompareQuantitationRatios.new
