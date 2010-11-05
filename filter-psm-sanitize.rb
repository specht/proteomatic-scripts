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
require './include/ruby/misc'
require 'set'
require 'yaml'
require 'bigdecimal'


class FilterPsmSanitize < ProteomaticScript
    def run()
        @output.each_pair do |inPath, outPath|
            File::open(outPath, 'w') do |fout|
                puts File::basename(inPath)
                scanHash = Hash.new
                filenameidIndex = nil
                peptideIndex = nil
                evalueIndex = nil
                File::open(inPath, 'r') do |fin|
                    headerLine = fin.readline
                    fout.puts headerLine
                    header = mapCsvHeader(headerLine)
                    filenameidIndex = header['filenameid']
                    unless filenameidIndex
                        puts "Error: missing 'filename/id' column in #{File::basename(inPath)}."
                        exit(1)
                    end
                    peptideIndex = header['peptide']
                    unless peptideIndex
                        puts "Error: missing 'peptide' column in #{File::basename(inPath)}."
                        exit(1)
                    end
                    evalueIndex = header['evalue']
                    unless evalueIndex
                        puts "Error: missing 'e-value' column in #{File::basename(inPath)}."
                        exit(1)
                    end
                    print 'Analyzing, '
                    fin.each_line do |line|
                        lineArray = line.parse_csv()
                        scanId = lineArray[filenameidIndex]
                        peptide = lineArray[peptideIndex]
                        evalue = BigDecimal.new(lineArray[evalueIndex])
                        scanHash[scanId] ||= [evalue, Set.new([peptide])]
                        if evalue < scanHash[scanId][0]
                            # replace scan results because we have found a better e-value
                            scanHash[scanId] = [evalue, Set.new([peptide])]
                        elsif evalue == scanHash[scanId][0]
                            scanHash[scanId][1] << peptide
                        end
                    end
                end
                totalRowCount = 0
                printedRowCount = 0
                File::open(inPath, 'r') do |fin|
                    fin.readline
                    print 'filtering, '
                    fin.each_line do |line|
                        totalRowCount += 1
                        lineArray = line.parse_csv()
                        scanId = lineArray[filenameidIndex]
                        evalue = BigDecimal.new(lineArray[evalueIndex])
                        if scanHash[scanId][0] == evalue
                            if scanHash[scanId][1].size == 1
                                fout.puts line
                                printedRowCount += 1
                            end
                        end
                    end
                end
                puts "done (removed #{totalRowCount - printedRowCount} of #{totalRowCount} rows)."
            end
        end
    end
end

lk_Object = FilterPsmSanitize.new
