# Copyright (c) 2009 Michael Specht
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

class ExtractCsvColumn < ProteomaticScript
	def run()
        column = stripCsvHeader(@param[:column])
        items = Array.new
        @input[:in].each do |path|
            File::open(path, 'r') do |f|
                header = mapCsvHeader(f.readline)
                if header.include?(column)
                    f.each_line do |line|
                        lineArray = line.parse_csv()
                        items << lineArray[header[column]]
                    end
                else
                    puts "Warning: Column '#{@param[:column]}' not found in #{path}."
                end
            end
        end
        if @param[:upcase]
            items.collect! { |x| x.upcase }
        end
        items.sort! if @param[:sort]
        items.uniq! if @param[:uniq]
        puts "Number of entries: #{items.size}."
	end
end

lk_Object = ExtractCsvColumn.new
