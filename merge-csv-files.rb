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

class MergeCsvFiles < ProteomaticScript
	def run()
        mergedFile = nil
        mergedFile = File::open(@output[:merged], 'w') if @output[:merged]
        # check for consistent CSV header in all input files
        headerLine = nil
        allHeader = nil
        @input[:in].each do |path|
            File::open(path, 'r') do |f|
                headerLine = f.readline
                header = mapCsvHeader(headerLine)
                allHeader ||= header
                if header != allHeader
                    puts "Error: The CSV header must be the same throughout all input files."
                    exit 1
                end
            end
        end
        
        mergedFile.puts headerLine if mergedFile
        
        totalCount = 0
        
        @input[:in].each do |path|
            File::open(path, 'r') do |f|
                f.readline
                f.each_line do |line|
                    totalCount += 1
                    print "\rMerging #{totalCount} entries..." if (totalCount % 200) == 0
                    mergedFile.puts line if mergedFile
                end
            end
        end
        puts "\rMerging #{totalCount} entries... done."
        
        mergedFile.close if mergedFile
	end
end

lk_Object = MergeCsvFiles.new
