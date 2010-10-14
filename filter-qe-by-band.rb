# Copyright (c) 2007-2010 Michael Specht
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
require 'include/ruby/ext/fastercsv'
require 'include/ruby/misc'
require 'set'
require 'yaml'

# This script picks the most abundant band for each quantified peptide/protein
# and discards all results that were found in other bands. If scope is set to
# automatic, protein is chosen when the protein column is found in all QE files.

class FilterQuantitationEventsByBand < ProteomaticScript
    def run()
        # handle band numbers that should be excluded
        lk_ExcludeBandNumbers = Set.new
        unless @param[:excludeBands].strip.empty?
            lk_Items = @param[:excludeBands].split(%r{[,;\s/]+})
            lk_Items.each do |ls_Item|
                li_Number = nil
                begin
                    li_Number = Integer(ls_Item)
                rescue ArgumentError
                    puts "Warning: #{ls_Item} (from the 'exclude bands' parameter) is not a valid number."
                    li_Number = nil
                    next
                end
                lk_ExcludeBandNumbers.add(li_Number) if li_Number
            end
        end
        unless lk_ExcludeBandNumbers.empty?
            puts "Excluding band#{lk_ExcludeBandNumbers.size == 1 ? '' : 's'} #{lk_ExcludeBandNumbers.to_a.sort.join(', ')} from most abundant band determination."
        end
        
        # test whether QE CSV headers are all the same
        ls_AllHeader = nil
        lk_AllHeader = nil
        @input[:quantitationEvents].each do |ls_InPath|
            File::open(ls_InPath, 'r') do |lk_In|
                ls_Header = lk_In.readline
                lk_Header = Set.new(mapCsvHeader(ls_Header).keys())
                ls_AllHeader ||= ls_Header
                lk_AllHeader = lk_Header
                if lk_Header != lk_AllHeader
                    puts "Error: The CSV header was not consistent throughout all quantitation event input files. The offending header line was #{ls_Header}."
                    exit 1
                end
            end
        end
        
        # determine scope
        ls_Scope = @param[:scope]
        if ls_Scope == 'automatic'
            # determine actual scope based on input files
            lb_HaveProteinInAllFiles = true
            @input[:quantitationEvents].each do |ls_Path|
                File::open(ls_Path, 'r') do |lk_File|
                    lk_Header = mapCsvHeader(lk_File.readline)
                    lb_HaveProteinInAllFiles = false unless lk_Header.include?('protein')
                end
            end
            ls_Scope = lb_HaveProteinInAllFiles ? 'protein' : 'peptide'
            puts "Auto-selecting #{ls_Scope} scope for most abundant band determination."
        end
        # scope is either 'peptide' or 'protein' now!
        
        # if scope is 'protein', get peptide => protein info from QE files
        # ...and check consistency on the way!
        lk_PeptideToProtein = Hash.new
        if (ls_Scope == 'protein')
            print 'Reading peptide => protein assignments from QE files...'
            @input[:quantitationEvents].each do |ls_InPath|
                File::open(ls_InPath, 'r') do |lk_In|
                    ls_Header = lk_In.readline
                    lk_Header = mapCsvHeader(ls_Header)
                    unless lk_Header.include?('protein')
                        puts "Error: There is no protein column in #{ls_InPath}."
                        exit
                    end
                    lk_In.each_line do |ls_Line|
                        lk_Line = ls_Line.parse_csv()
                        ls_Protein = lk_Line[lk_Header['protein']]
                        ls_Peptide = lk_Line[lk_Header['peptide']]
                        if lk_PeptideToProtein.include?(ls_Peptide)
                            if lk_PeptideToProtein[ls_Peptide] != ls_Protein
                                puts "Error: The peptide => protein assignments are not consistent in #{ls_InPath}."
                                puts "The offending pair was #{ls_Peptide} => #{ls_Protein}."
                                puts "In another quantitation event, the peptide was assigned to a different protein."
                                exit
                            end
                        end
                        lk_PeptideToProtein[ls_Peptide] = ls_Protein
                    end
                end
            end
            puts
        end
        lk_BestBandForItem = Hash.new
        
        lk_BandNumberForSpotName = Hash.new
        lk_BandToRun = Hash.new
        print 'Reading PSM lists, determining best bands...'
        @input[:psmList].each do |ls_PsmPath|
            ls_RunName = File::basename(ls_PsmPath).sub('.csv', '')
            lk_BestBandForItem[ls_RunName] = Hash.new
            lk_Spots = Set.new
            #print "Loading #{File::basename(ls_PsmPath)}..."
            lk_Results = loadPsm(ls_PsmPath, :silent => true)
            #puts ''
            lk_Results[:spectralCounts][:peptides].values.each do |lk_BandHash|
                lk_Spots += Set.new(lk_BandHash.keys.reject { |x| x.class != String })
            end
            lk_Spots.each { |ls_Spot| lk_BandToRun[ls_Spot] = ls_RunName }
            ls_AllPattern = nil
            lk_AllParts = Array.new
#             puts "Spots: #{lk_Spots.to_a.sort.join(', ')}"
            lk_Spots.each do |ls_Spot|
                ls_Pattern, lk_Parts = splitNumbersAndLetters(ls_Spot)
                unless ls_AllPattern
                    ls_AllPattern = ls_Pattern
                    lk_Parts.each { |ls_Part| lk_AllParts.push({ls_Part => ls_Spot}) }
                else
                    if ls_AllPattern != ls_Pattern
                        puts "Error: The band numbers could not be determined because the spot names are inconsistent. The first offending spot name was #{ls_Spot}."
                        puts "Global pattern: #{ls_AllPattern}, other pattern: #{ls_Pattern}"
                        exit 1
                    end
                    (0...lk_Parts.size).each { |i| lk_AllParts[i][lk_Parts[i]] = ls_Spot }
                end
            end
            lk_ItemsWithMultipleValues = Array.new
            (0...lk_AllParts.size).each do |i|
                lk_ItemsWithMultipleValues << i if lk_AllParts[i].size != 1
            end
            # now only one part should be left, and this should be a number, too!
            if @param[:bandIndex].strip.empty?
                if (lk_ItemsWithMultipleValues.size != 1)
                    puts "Error: The band numbers could not be determined because there's more than one variable number in the spot names."
                    puts "In order to remedy this problem, please supply the correct band ID that identifies the band number as a parameter and re-run the script." 
                    lk_ItemsWithMultipleValues.each do |i|
                        puts
                        puts "ID: #{i} (choose this if you see band numbers below)"
                        puts lk_AllParts[i].keys.sort.join(', ')
                    end
                    exit 1
                end
                lk_AllParts.reject! { |x| x.size == 1 }
                lk_AllParts.first.each_pair do |ls_BandNumber, ls_SpotName|
                    li_BandNumber = ls_BandNumber.to_i
                    lk_BandNumberForSpotName[ls_SpotName] = li_BandNumber
                end
            else
                # a band ID was defined, use it
                lk_AllParts[@param[:bandIndex].to_i].each_pair do |ls_BandNumber, ls_SpotName|
                    li_BandNumber = ls_BandNumber.to_i
                    lk_BandNumberForSpotName[ls_SpotName] = li_BandNumber
                end
            end
            
             lk_Results[:spectralCounts][:peptides].each_pair do |ls_Item, lk_SpectralCounts|
                ls_FixedItem = ls_Item.dup
                
                # promote to protein if protein scope!
                ls_FixedItem = lk_PeptideToProtein[ls_FixedItem] if (ls_Scope == 'protein')
                
                # maybe remove leading fasta filename thing... like nr-Chlre3.fasta;
                
                # select most appropriate bands for each item
                lk_BandCounts = Hash.new
                lk_SpectralCounts.each_pair do |ls_Band, li_Count|
                    next unless ls_Band.class == String
                    li_BandNumber = lk_BandNumberForSpotName[ls_Band]
                    unless li_BandNumber
                        puts "Internal error: Unable to determine band number for band name '#{ls_Band}'."
                        exit 1
                    end
                    next if lk_ExcludeBandNumbers.include?(li_BandNumber)
                    lk_BandCounts[li_BandNumber] = li_Count
                end
                li_BestBand = nil
                lk_SingleBandCounts = lk_BandCounts.dup
                lk_NeighborBandCounts = lk_BandCounts.dup
                lk_BandCounts.keys.each do |li_Band|
                    lk_NeighborBandCounts[li_Band] += lk_BandCounts[li_Band - 1] if lk_BandCounts[li_Band - 1]
                    lk_NeighborBandCounts[li_Band] += lk_BandCounts[li_Band + 1] if lk_BandCounts[li_Band + 1]
                end
                lk_SingleKeysSorted = lk_SingleBandCounts.keys.sort { |a, b| lk_SingleBandCounts[b] <=> lk_SingleBandCounts[a] }
                li_HighestSingleKey = lk_SingleKeysSorted.first
                lk_SingleKeysSorted.reject! { |x| lk_SingleBandCounts[x] != lk_SingleBandCounts[li_HighestSingleKey] }
                if (lk_SingleKeysSorted.size == 1)
                    # there is a single band with the highest spectral count, pick it
                    li_BestBand = lk_SingleKeysSorted.first
                else
                    # there are several bands with the equal highest spectral count, choose according to neighbors
                    lk_NeighborKeysSorted = lk_NeighborBandCounts.keys.sort { |a, b| lk_NeighborBandCounts[b] <=> lk_NeighborBandCounts[a] }
                    li_HighestNeighborKey = lk_NeighborKeysSorted.first
                    lk_NeighborKeysSorted.reject! { |x| lk_NeighborBandCounts[x] != lk_NeighborBandCounts[li_HighestNeighborKey] }
                    li_BestBand = lk_NeighborKeysSorted.first
                end
                lk_BestBandForItem[ls_RunName][ls_FixedItem] = li_BestBand
            end
        end
        puts
        if @output[:results]
            File::open(@output[:results], 'w') do |lk_Out|
                print 'Writing filtered results...'
                li_InCount = 0
                li_OutCount = 0
                lk_Out.puts ls_AllHeader
                @input[:quantitationEvents].each do |ls_InPath|
                    File::open(ls_InPath, 'r') do |lk_In|
                        ls_Header = lk_In.readline
                        lk_Header = mapCsvHeader(ls_Header)
                        lk_In.each_line do |ls_Line|
                            li_InCount += 1
                            lk_Line = ls_Line.parse_csv()
                            ls_Band = lk_Line[lk_Header['filename']].split('.').first
                            ls_Protein = lk_Line[lk_Header[ls_Scope]]
                            ls_Run = lk_BandToRun[ls_Band]
                            if ls_Run
                                li_BestBand = lk_BestBandForItem[ls_Run][ls_Protein]
                                if li_BestBand
                                    if (li_BestBand - lk_BandNumberForSpotName[ls_Band]).abs <= @param[:neighborBandCount]
                                        lk_Out.puts ls_Line
                                        li_OutCount += 1
                                    end
                                end
                            end
                        end
                    end
                end
                puts
                puts "Discarded #{li_InCount - li_OutCount} of #{li_InCount} hits (#{sprintf('%1.1f', (li_InCount - li_OutCount).to_f / li_InCount.to_f * 100.0)}%)."
            end
        end
    end
end

lk_Object = FilterQuantitationEventsByBand.new
