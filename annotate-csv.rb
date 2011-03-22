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
        csvHeaders = allCsvHeaders(@input[:in], false)
        if csvHeaders.size > 1
            puts "Error: CSV headers are not the same in all input files."
            exit(1)
        end
        unless csvHeaders.to_a.first.collect { |x| stripCsvHeader(x) }.include?(stripCsvHeader(@param[:keyInput]))
            puts "Error: No '#{@param[:keyInput]}' column found in the input file#{@input[:in].size == 1 ? '' : 's'}."
            exit(1)
        end
        keyAnnotation = stripCsvHeader(@param[:keyAnnotation])
        valueAnnotation = stripCsvHeader(@param[:valueAnnotation])
        # the annotation is a key => [value 1, value 2, ...] dict, with mostly
        # a single value per key but more are possible. Multiple values per key
        # result in multiple output lines in the annotated CSV file.
        annotation = Hash.new
        print "Reading annotation... "
        File::open(@input[:annotation].first) do |f|
            header = mapCsvHeader(f.readline)
            unless header.include?(keyAnnotation)
                puts "Error: No '#{@param[:keyAnnotation]}' column found in #{File::basename(@input[:annotation].first)}."
                exit(1)
            end
            unless header.include?(valueAnnotation)
                puts "Error: No '#{@param[:valueAnnotation]}' column found in #{File::basename(@input[:annotation].first)}."
                exit(1)
            end
            f.each_line do |line|
                lineArray = line.parse_csv()
                key = lineArray[header[keyAnnotation]]
                value = lineArray[header[valueAnnotation]]
                key = key.strip if @param[:stripLookupValue]
                key = key.downcase if @param[:downcaseLookupValue]
                annotation[key] ||= []
                annotation[key] << value
            end
        end
        puts "done."
        
        inputLineCount = 0
        outputLineCount = 0
        emptyOutputLineCount = 0
        
        print "Annotating CSV rows... "
        if @output[:result]
            wroteHeader = false
            File::open(@output[:result], 'w') do |fout|
                @input[:in].each do |inPath|
                    File::open(inPath, 'r') do |fin|
                        headerLine = fin.readline
                        unless wroteHeader
                            fout.puts headerLine.strip + ",\"#{@param[:newColumnName]}\""
                            wroteHeader = true
                        end
                        header = mapCsvHeader(headerLine)
                        keyIndex = header[stripCsvHeader(@param[:keyInput])]
                        fin.each_line do |line|
                            inputLineCount += 1
                            if inputLineCount % 1000 == 0
                                print "\rAnnotating #{inputLineCount} CSV rows... "
                            end
                            lineArray = line.parse_csv()
                            lookup = lineArray[keyIndex]
                            lookup = lookup.strip if @param[:stripLookupValue]
                            lookup = lookup.downcase if @param[:downcaseLookupValue]
                            if annotation[lookup]
                                annotation[lookup].each do |value|
                                    fout.puts line.strip + ",\"#{value}\""
                                    outputLineCount += 1
                                end
                            else
                                fout.puts line.strip + ",\"\""
                                outputLineCount += 1
                                emptyOutputLineCount += 1
                            end
                        end
                    end
                end
            end
        end
        puts "\rAnnotating #{inputLineCount} CSV rows, wrote #{outputLineCount} rows (#{emptyOutputLineCount} without annotation), done."
    end
end

script = DuplicateCsvColumn.new
