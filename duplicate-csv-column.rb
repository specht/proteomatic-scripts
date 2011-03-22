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
        colA = stripCsvHeader(@param[:columnA])
        colB = @param[:columnB]
        @output.each_pair do |inPath, outPath|
            File::open(outPath, 'w') do |fout|
                File::open(inPath, 'r') do |fin|
                    headerLine = fin.readline
                    headerList = headerLine.parse_csv()
                    header = mapCsvHeader(headerLine)
                    indexA = header[colA]
                    indexB = header[colB]
                    if !indexA
                        puts "Error: A column named '#{@param[:columnA]}' was not found in #{inPath}."
                        exit 1
                    end
                    if indexB
                        puts "Error: A column named '#{@param[:columnB]}' is already contained in #{inPath}."
                        exit 1
                    end
                    headerList << colB
                    fout.puts headerList.to_csv
                    print "Duplicating entries from column '#{@param[:columnA]}'..."
                    fin.each_line do |line|
                        lineArray = line.parse_csv()
                        lineArray << lineArray[indexA]
                        fout.puts lineArray.to_csv
                    end
                    puts 'done.'
                end
            end
        end
    end
end

script = DuplicateCsvColumn.new
