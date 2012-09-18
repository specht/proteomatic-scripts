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


class FilterPsmSanitize < ProteomaticScript
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
            deflineIndex = nil
            evalueIndex = nil
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
                deflineIndex = header['defline']
                unless deflineIndex
                    puts "Error: missing 'defline' column in #{File::basename(inPath)}."
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
                    peptide.upcase! if @param[:upcasePeptides]
                    evalue = BigDecimal.new(lineArray[evalueIndex])
                    scanHash[scanId] ||= Hash.new
                    scanHash[scanId][peptide] ||= evalue
                    scanHash[scanId][peptide] = evalue if evalue < scanHash[scanId][peptide]
                end
            end
            secondBestHitRatios = Hash.new
            bestPeptideForScan = Hash.new
            scanHash.keys.each do |scanId|
                peptides = scanHash[scanId].keys.sort do |a, b|
                    scanHash[scanId][a] <=> scanHash[scanId][b]
                end
                bestPeptide = peptides.first
                bestScore = scanHash[scanId][bestPeptide]
                ratio = 1000.0
                if peptides.size > 1
                    nextBestPeptide = peptides[1]
                    nextBestScore = scanHash[scanId][nextBestPeptide]
                    if bestScore == 0.0
                        # if the best score is 0.0, this is a bit fishy, so here's how we deal
                        # with it: keep one of the peptides but denote via a distinctiveness of 0
                        # that it's probably no good
                        ratio = 0.0
                    else
                        ratio = Math::log(nextBestScore / bestScore) / log10
                    end
                    ratio = 1000.0 if ratio > 1000.0
                end
                secondBestHitRatios[scanId] = ratio
                bestPeptideForScan[scanId] = bestPeptide
            end
            File::open(inPath, 'r') do |fin|
                fin.readline
                fin.each_line do |line|
                    totalRowCount += 1
                    lineArray = line.parse_csv()
                    scanId = lineArray[filenameidIndex]
                    peptide = lineArray[peptideIndex].dup
                    peptide.upcase! if @param[:upcasePeptides]
                    defline = lineArray[deflineIndex]
#                         evalue = BigDecimal.new(lineArray[evalueIndex])
                    keepThis = false
                    if bestPeptideForScan[scanId] == peptide
                        if secondBestHitRatios[scanId].to_f >= @param[:threshold]
                            keepThis = true
                        end
                    end
                    
                    if @param[:removeSimilarGpfPeptides]
                        if defline.index('__putative__gpf_') == 0
                            gpfPeptide = defline.sub('__putative__gpf_', '')
                            keepThis = false if gpfPeptide != peptide
                        end
                    end
                    
                    if keepThis
                        outFile.puts line.strip + ",#{sprintf('%1.2f', secondBestHitRatios[scanId].to_f)}" if outFile
                        printedRowCount += 1
                    else
                        discardFile.puts line.strip + ",#{sprintf('%1.2f', secondBestHitRatios[scanId].to_f)}" if discardFile
                    end
                end
            end
        end
        puts "Removed #{totalRowCount - printedRowCount} of #{totalRowCount} rows."
        outFile.close if outFile
        discardFile.close if discardFile
    end
end

script = FilterPsmSanitize.new
