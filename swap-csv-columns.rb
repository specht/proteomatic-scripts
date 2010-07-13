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
require 'fileutils'

class SwapCsvColumns < ProteomaticScript
	def run()
        colA = stripCsvHeader(@param[:columnA])
        colB = stripCsvHeader(@param[:columnB])
        @output.each_pair do |inPath, outPath|
            File::open(outPath, 'w') do |fout|
                File::open(inPath, 'r') do |fin|
                    headerLine = fin.readline
                    headerList = headerLine.parse_csv()
                    header = mapCsvHeader(headerLine)
                    indexA = header[colA]
                    indexB = header[colB]
                    if !indexA || !indexB
                        puts "Error: At least one of the columns specified was not found in #{inPath}."
                        exit 1
                    end
                    temp = headerList[indexA]
                    headerList[indexA] = headerList[indexB]
                    headerList[indexB] = temp
                    fout.puts headerList.to_csv
                    print "Swapped header columns, copying rows..."
                    fin.each_line do |line|
                        fout.puts line
                    end
                    puts 'done.'
                end
            end
        end
	end
end

lk_Object = SwapCsvColumns.new
