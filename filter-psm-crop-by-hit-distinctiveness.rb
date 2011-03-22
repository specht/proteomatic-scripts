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
require './include/ruby/misc'
require 'set'
require 'yaml'
require 'bigdecimal'


class CropPsmByHitDistinctivenes < ProteomaticScript
    def run()
        outFile = nil
        outFile = File::open(@output[:results], 'w') if @output[:results]
        discardFile = nil
        discardFile = File::open(@output[:discarded], 'w') if @output[:discarded]
        totalRowCount = 0
        printedRowCount = 0
        puts "Reading PSM list files..."
        log10 = Math::log(10.0)
        allHeader = nil
        wroteHeader = false
        @input[:omssaResults].each do |inPath|
            File::open(inPath) do |f|
                header = mapCsvHeader(f.readline)
                allHeader ||= header
                if (header != allHeader)
                    puts "Error: The CSV header is not the same in all input files."
                    exit 1
                end
            end
        end
        @input[:omssaResults].each do |inPath|
            puts File::basename(inPath)
            scanHash = Hash.new
            filenameidIndex = nil
            peptideIndex = nil
            evalueIndex = nil
            bestScoreForScan = Hash.new
            File::open(inPath, 'r') do |fin|
                headerLine = fin.readline
                unless wroteHeader
                    outFile.puts headerLine.strip + ',Hit distinctiveness' if outFile
                    discardFile.puts headerLine.strip + ',Hit distinctiveness' if discardFile
                    wroteHeader = true
                end
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
                fin.each_line do |line|
                    lineArray = line.parse_csv()
                    scanId = lineArray[filenameidIndex]
                    peptide = lineArray[peptideIndex].dup
                    evalue = BigDecimal.new(lineArray[evalueIndex])
                    bestScoreForScan[scanId] ||= evalue
                    bestScoreForScan[scanId] = evalue if evalue < bestScoreForScan[scanId]
                    scanHash[scanId] ||= Hash.new
                    scanHash[scanId][peptide] ||= evalue
                    scanHash[scanId][peptide] = evalue if evalue < scanHash[scanId][peptide]
                end
            end
            
            File::open(inPath, 'r') do |fin|
                fin.readline
                fin.each_line do |line|
                    totalRowCount += 1
                    lineArray = line.parse_csv()
                    scanId = lineArray[filenameidIndex]
                    peptide = lineArray[peptideIndex].dup
                    evalue = BigDecimal.new(lineArray[evalueIndex])
                    printedIt = false
                    hitDistinctiveness = Math::log(evalue) - Math::log(bestScoreForScan[scanId])
                    if hitDistinctiveness <= @param[:threshold]
                        outFile.puts line.strip + ",#{sprintf('%1.2f', hitDistinctiveness)}" if outFile
                        printedRowCount += 1
                        printedIt = true
                    end
                    unless printedIt
                        discardFile.puts line.strip + ",#{sprintf('%1.2f', hitDistinctiveness)}" if discardFile
                    end
                end
            end
        end
        puts "Removed #{totalRowCount - printedRowCount} of #{totalRowCount} rows."
        outFile.close if outFile
        discardFile.close if discardFile
    end
end

script = CropPsmByHitDistinctivenes.new
