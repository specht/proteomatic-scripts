#! /usr/bin/env ruby
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

class DuplicateCsvColumn < ProteomaticScript
    def run()
        keyColumn = stripCsvHeader(@param[:keyColumn])

        csvHeaders = allCsvHeaders(@input[:in])
        csvHeaders.each do |headerList|
            unless headerList.include?(keyColumn)
                puts "Error: The '#{@param[:keyColumn]}' column was not found in all input files."
                exit(1)
            end
        end
        
        fileHash = Hash.new
        @input[:in].each do |path|
            fileHash[File::basename(path).split('.').first] = path
        end

        if @output[:result]
            File::open(@output[:result], 'w') do |fout|
                # write joined header
                fout.print "\"#{@param[:keyColumn]}\""
                keyIndex = Hash.new
                columnCount = Hash.new
                fileHash.each_pair do |key, path|
                    File::open(path, 'r') do |f|
                        headerLine = f.readline
                        header = headerLine.parse_csv()
                        headerMap = mapCsvHeader(headerLine)
                        keyIndex[key] = headerMap[keyColumn]
                        header.delete_at(keyIndex[key])
                        columnCount[key] = header.size
                        fout.print(',' + header.collect {|x| x + ' ' + key }.to_csv().strip)
                    end
                end
                fout.puts
                
                # load all data
                allLines = Hash.new
                fileHash.each_pair do |key, path|
                    File::open(path, 'r') do |fin|
                        headerLine = fin.readline
                        header = headerLine.parse_csv()
                        headerMap = mapCsvHeader(headerLine)
                        fin.each_line do |line|
                            lineArray = line.parse_csv()
                            lookupValue = lineArray[headerMap[keyColumn]]
                            lineArray.delete_at(keyIndex[key])
                            allLines[lookupValue] ||= Hash.new
                            allLines[lookupValue][key] ||= []
                            allLines[lookupValue][key] << lineArray
                        end
                    end
                end
                
                # write joined data
                allLines.keys.sort.each do |lookupValue|
                    # skip this entry if there are more than one corresponding rows 
                    # in a single input file
                    allLines[lookupValue].values.each do |lines|
                        next unless lines.size == 1
                    end
                    fout.print "\"#{lookupValue}\""
                    fileHash.each_pair do |key, path|
                        if allLines[lookupValue][key]
                            fout.print ',' + allLines[lookupValue][key].first.to_csv().strip
                        else
                            fout.print ',' * columnCount[key]
                        end
                    end
                    fout.puts
                end
            end
        end
    end
end

script = DuplicateCsvColumn.new
