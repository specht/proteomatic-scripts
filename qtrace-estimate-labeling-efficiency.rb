# Copyright (c) 2007-2008 Michael Specht
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
require 'include/ruby/evaluate-omssa-helper'
require 'include/ruby/externaltools'
require 'include/ruby/fasta'
require 'include/ruby/formats'
require 'include/ruby/misc'
require 'bigdecimal'
require 'fileutils'
require 'yaml'


class QTraceEstimateLabelingEfficiency < ProteomaticScript
	def run()
		# get peptides from PSM list
        results = loadPsm(@input[:psmFile].first, :silent => false) 

        peptidesBySpectralCount = results[:peptideHash].keys.sort do |a, b|
            results[:peptideHash][b][:scans].size <=> results[:peptideHash][a][:scans].size
        end
        
        searchPeptides = peptidesBySpectralCount[0, @param[:peptideCount]]
        
        if searchPeptides.empty?
            puts "Error: No peptides could be extracted from the PSM list file."
            exit(1)
        end
        
        if searchPeptides.size < @param[:peptideCount]
            puts "Warning: Only #{searchPeptides.size} peptide#{searchPeptides.size > 1 ? 's' : ''} can be used for the estimation, although #{@param[:peptideCount]} were specified."
        end

        puts 'Determining most abundant peptides...'
        # pick most abundant band for each peptide
        searchPeptidesInBands = Hash.new
        searchPeptides.each do |peptide|
            sortedSpots = results[:peptideHash][peptide][:spots].sort do |a, b|
                results[:spectralCounts][:peptides][peptide][b] <=> results[:spectralCounts][:peptides][peptide][a]
            end
            bestSpot = sortedSpots.first
            searchPeptidesInBands[bestSpot] ||= Hash.new
            retentionTimes = Array.new
            scanEValues = Hash.new
            results[:peptideHash][peptide][:scans].each do |scan|
                next unless (scan.index(bestSpot) == 0)
                scanEValues[results[:scanHash][scan][:retentionTime]] = results[:scanHash][scan][:e]
            end
            scanEValuesSorted = scanEValues.keys.sort do |a, b|
                scanEValues[a] <=> scanEValues[b]
            end
            bestScan = scanEValuesSorted.first
            bestScanRt = bestScan
            searchPeptidesInBands[bestSpot][peptide] = bestScanRt
        end
        
        puts "Searching for #{searchPeptides.size} peptides in #{searchPeptidesInBands.size} bands:"
        searchPeptidesInBands.each do |band, peptides|
            puts "#{band}: #{peptides.keys.collect { |p| p + ' (RT ' + sprintf('%1.1f', peptides[p]) + ')' }.join(', ')}"
        end
	end
end

lk_Object = QTraceEstimateLabelingEfficiency.new
