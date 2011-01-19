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
require 'yaml'
require 'set'


class GffLengthHistogram < ProteomaticScript
    def run()
        histogram = Hash.new
        maxBin = 0
        @input[:input].each do |path|
            File::open(path) do |f|
                lineCounter = 0
                f.each_line do |line|
                    lineCounter += 1
                    print "\rProcessed #{lineCounter} lines..." if lineCounter % 100 == 0
                    line.strip!
                    next if line.empty?
                    next if line[0, 1] == '#'
                    lineArray = line.split("\t")
                    if lineArray.size != 9
                        puts "Error: Wrong number of columns (expected 9, got #{lineArray.size} in line #{lineCounter})."
                        exit(1)
                    end
                    type = lineArray[2]
                    start = lineArray[3].to_i
                    stop = lineArray[4].to_i
                    length = stop - start + 1
                    bin = (length / @param[:binSize]).to_i * @param[:binSize]
                    maxBin = bin if bin > maxBin
                    histogram[type] ||= Hash.new
                    histogram[type] ||= Hash.new
                    histogram[type][bin] ||= 0
                    histogram[type][bin] += 1
                end
                puts "\rProcessed #{lineCounter} lines... done."
            end
        end
        puts "Found #{histogram.size} distinct features, max length is ~#{maxBin}."
        columns = histogram.keys.sort
        if @output[:histogram]
            File::open(@output[:histogram], 'w') do |fout|
                fout.puts("Length bin," + columns.collect { |x| '"' + x + '"' }.join(','))
                bin = 0
                while bin <= maxBin
                    fout.puts("#{bin}," + columns.collect { |x| histogram[x].include?(bin) ? histogram[x][bin].to_s : '0' }.join(','))
                    bin += @param[:binSize]
                end
            end
        end
    end
end


script = GffLengthHistogram.new
