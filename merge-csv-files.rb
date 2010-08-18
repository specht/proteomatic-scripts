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
require 'include/ruby/externaltools'
require 'include/ruby/misc'
require 'include/ruby/ext/fastercsv'
require 'yaml'
require 'set'
require 'fileutils'

# Merge CSV files works as follows:
# - check whether all headers are exactly the same -> do simple merge
# - if not, check whether all headers contain the same columns, but maybe
#   in a different order (resulting from a column swap maybe) 
#   -> do re-arranging merge
# - else fail

class MergeCsvFiles < ProteomaticScript
    
    def simpleMerge(paths)
        headerLine = nil
        File::open(@output[:merged], 'w') do |fout|
            totalCount = 0
            @input[:in].each do |path|
                File::open(path, 'r') do |f|
                    thisHeaderLine = f.readline
                    unless headerLine
                        headerLine = thisHeaderLine
                        fout.puts headerLine
                    end
                    f.each_line do |line|
                        totalCount += 1
                        print "\rMerging #{totalCount} entries..." if (totalCount % 200) == 0
                        fout.puts line
                    end
                end
            end
            puts "\rMerging #{totalCount} entries... done."
        end
    end
    
    def rearrangingMerge(paths)
        header = nil
        reverseHeader = nil
        File::open(@output[:merged], 'w') do |fout|
            totalCount = 0
            @input[:in].each do |path|
                File::open(path, 'r') do |f|
                    thisHeaderLine = f.readline
                    thisHeader = mapCsvHeader(thisHeaderLine)
                    unless header
                        fout.puts thisHeaderLine
                        header = thisHeader
                        reverseHeader = header.invert
                    end
                    f.each_line do |line|
                        lineArray = line.parse_csv
                        totalCount += 1
                        print "\rMerging #{totalCount} entries..." if (totalCount % 200) == 0
                        newLineArray = []
                        reverseHeader.keys.sort.each do |i|
                            key = reverseHeader[i]
                            newLineArray << lineArray[thisHeader[key]]
                        end
                        fout.puts newLineArray.to_csv()
                    end
                end
            end
            puts "\rMerging #{totalCount} entries... done."
        end
    end
    
    def run()
        unless @output[:merged]
            puts "Notice: Doing nothing, because no output file has been requested."
            exit 0
        end
        
        # check for consistent CSV header in all input files
        allHeadersHaveDistinctFields = true
        distinctHeaderLists = Set.new
        distinctHeaderSets = Set.new
        @input[:in].each do |path|
            File::open(path, 'r') do |f|
                headerLine = f.readline
                headerList = headerLine.parse_csv()
                thisColumns = []
                headerList.each { |x| thisColumns << stripCsvHeader(x) }
                distinctHeaderLists << thisColumns
                distinctHeaderSets << Set.new(thisColumns)
                allHeadersHaveDistinctFields = false if Set.new(thisColumns).size != thisColumns.size
            end
        end
        
        if distinctHeaderLists.size == 1
            simpleMerge(@input[:in])
        elsif distinctHeaderSets.size == 1
            if allHeadersHaveDistinctFields
                rearrangingMerge(@input[:in])
            else
                puts "Error: Unable to perform a column-rearranging merge because there are duplicate columns in one of the input files."
                exit 1
            end
        else
            puts "Error: The header fields are not the same in all input files, unable to merge!"
            exit 1
        end
    end
end

lk_Object = MergeCsvFiles.new
