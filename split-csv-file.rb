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

require './include/ruby/proteomatic'
require './include/ruby/externaltools'
require './include/ruby/misc'
require './include/ruby/ext/fastercsv'
require 'yaml'
require 'fileutils'

class SplitCsvFile < ProteomaticScript
    def run()
        acceptFile = nil
        rejectFile = nil
        acceptFile = File::open(@output[:acceptedEntries], 'w') if @output[:acceptedEntries]
        rejectFile = File::open(@output[:rejectedEntries], 'w') if @output[:rejectedEntries]
        column = stripCsvHeader(@param[:column])
        headerLine = nil
        allHeader = nil
        @input[:in].each do |path|
            File::open(path, 'r') do |f|
                headerLine = f.readline
                header = mapCsvHeader(headerLine)
                unless header.include?(column)
                    puts "Error: There is no '#{column}' column in the input files."
                    exit 1
                end
                allHeader ||= header
                if header != allHeader
                    puts "Error: The CSV header must be the same throughout all input files."
                    exit 1
                end
            end
        end
        
        acceptFile.puts headerLine if acceptFile
        rejectFile.puts headerLine if rejectFile
        
        possibleValues = Set.new
        possibleValues << @param[:value]
        @input[:values].each do |path|
            possibleValues |= Set.new(File::read(path).split("\n").collect { |x| x.strip } )
        end
        possibleValues.reject! { |x| x.empty? }
        if @param[:caseSensitive] == 'no'
            possibleValues.collect! { |x| x.downcase }
        end
        
        acceptCount = 0
        rejectCount = 0
        totalCount = 0
        
        @input[:in].each do |path|
            File::open(path, 'r') do |f|
                f.readline
                f.each_line do |line|
                    totalCount += 1
                    print "\rReading #{totalCount} entries..." if (totalCount % 200) == 0
                    lineArray = line.parse_csv()
                    item = lineArray[allHeader[column]]
                    item.downcase! if @param[:caseSensitive] == 'no'
                    
                    allAccept = false
                    possibleValues.each do |value|
                        thisAccept = nil
                        if @param[:operand] == 'contains'
                            thisAccept = item.include?(value)
                        elsif @param[:operand] == 'equal'
                            thisAccept = (item == value)
                        elsif @param[:operand] == 'notEqual'
                            thisAccept = (item != value)
                        elsif @param[:operand] == 'less'
                            thisAccept = (item.to_f < value.to_f)
                        elsif @param[:operand] == 'lessOrEqual'
                            thisAccept = (item.to_f <= value.to_f)
                        elsif @param[:operand] == 'greater'
                            thisAccept = (item.to_f > value.to_f)
                        elsif @param[:operand] == 'greaterOrEqual'
                            thisAccept = (item.to_f >= value.to_f)
                        end
                        if thisAccept
                            allAccept = true
                            break
                        end
                    end
                    if allAccept
                        acceptFile.puts line if acceptFile
                        acceptCount += 1
                    else
                        rejectFile.puts line if rejectFile
                        rejectCount += 1
                    end
                end
            end
        end
        puts "\rReading #{totalCount} entries... done."
        
        acceptFile.close if acceptFile
        rejectFile.close if rejectFile
        puts "Accepted #{acceptCount} entries, rejected #{rejectCount} entries."
    end
end

lk_Object = SplitCsvFile.new
