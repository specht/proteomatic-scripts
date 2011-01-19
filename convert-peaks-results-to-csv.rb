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
require './include/ruby/ext/fastercsv'
require 'set'
require 'yaml'
require 'fileutils'

class PeaksResultsToCsv < ProteomaticScript
    
    def handleEntry(id, entry, out)
        return if (id.empty?) || (entry.empty?)
        # >/home/michael/antibody/temp-peaks20100819-10433-1et1ln2-0/in/xml2mgf-out.mgf 0 427.31537 2 19%
        # LPQPSRR
        score = id.slice!(id.rindex(' '), id.size).strip
        score = '0' if score == '<1'
        score = score.to_i
        id.strip!
        charge = id.slice!(id.rindex(' '), id.size).strip
        id.strip!
        precursorMz = id.slice!(id.rindex(' '), id.size).strip
        id.strip!
        scanId = id.slice!(id.rindex(' '), id.size).strip
        id.strip!
        filename = id
        out.puts "\"#{scanId}\",#{precursorMz},#{charge},#{score},\"#{entry}\""
    end

    def run()
        puts "\rConvert de novo peptides... #{@entryCount}."
        @output.each_pair do |inPath, outPath|
            File::open(outPath, 'w') do |outFile|
                outFile.puts "Id,Precursor m/z,Charge,Score,Peptide"
                File::open(inPath, 'r') do |inFile|
                    id = nil
                    entry = ''
                    inFile.each_line do |line|
                        line.strip!
                        if line[0, 1] == '>'
                            handleEntry(id, entry, outFile) if id
                            id = line[1, line.size - 1]
                            entry = ''
                        else
                            entry += line
                        end
                    end
                    handleEntry(id, entry, outFile) if id
                end
            end
        end
    end
end

script = PeaksResultsToCsv.new
