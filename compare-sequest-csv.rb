#! /usr/bin/env ruby
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

require './include/ruby/proteomatic'
require './include/ruby/evaluate-omssa-helper'
require './include/ruby/ext/fastercsv'
require './include/ruby/misc'
require 'set'
require 'yaml'

class CompareSequestCsv < ProteomaticScript
    def run()
        lk_Files = @input[:csvFile]
        lk_Ids = lk_Files.collect { |x| File::basename(x).sub('.csv', '') }.sort

        lk_ScanHash = Hash.new

        lk_Files.each do |ls_Path|
            ls_Id = File::basename(ls_Path).sub('.csv', '')
            ls_Protein = nil
            lk_ForbiddenScanIds = Set.new
            File::open(ls_Path, 'r') do |lk_File|
                lk_File.each_line do |ls_Line|
                    lk_Line = ls_Line.parse_csv
                    if (lk_Line[0] && (!lk_Line[0].empty?))
                        # here comes a protein
                        ls_Protein = lk_Line[1]#.sub('nr-chlre-Chlre3_1.GeneCatalogProteins.6JUL06.fasta;', '')
                        next
                    end
                    if (ls_Protein && lk_Line[2])
                        # here comes a peptide
                        ls_ScanId = ls_Path + '/' + lk_Line[1]
                        next if lk_ForbiddenScanIds.include?(ls_ScanId)
                        ls_Peptide = lk_Line[2]
                        ls_CleanPeptide = ls_Peptide.gsub('*', '').split('.')[1]
                        if lk_ScanHash.include?(ls_ScanId)
                            # scan already there
                            if (lk_ScanHash[ls_ScanId][:cleanPeptide] != ls_CleanPeptide)
                                puts "ignoring ambiguous match in #{File::basename(ls_Path)}, scan id #{ls_ScanId.split('/').last}, #{lk_ScanHash[ls_ScanId][:cleanPeptide]} / #{ls_CleanPeptide}"
                                lk_ForbiddenScanIds.add(ls_ScanId)
                                lk_ScanHash.delete(ls_ScanId)
                            end
                        end
                        unless lk_ForbiddenScanIds.include?(ls_ScanId)
                            lk_ScanHash[ls_ScanId] ||= {:cleanPeptide => ls_CleanPeptide, :protein => ls_Protein, :starPeptides => Set.new, :id => ls_Id }
                            lk_ScanHash[ls_ScanId][:starPeptides].add(ls_Peptide)
                        end
                    end
                end
            end
        end

        def buildProteinTable(ak_ScanHash, ak_Ids, ak_Options = {})
            lk_Proteins = Hash.new
            ak_ScanHash.each do |ls_ScanId, lk_Scan|
                lk_Proteins[lk_Scan[:protein]] ||= Hash.new
                lk_Proteins[lk_Scan[:protein]][:peptides] ||= Hash.new
                ls_Peptide = lk_Scan[:cleanPeptide]
                lb_AnyModifiedPeptides = false
                
                lk_Scan[:starPeptides].each do |x|
                    lb_AnyModifiedPeptides = true if x.include?('*')
                end
                next if (ak_Options[:modifiedOnly] && (!lb_AnyModifiedPeptides))
                
                ls_Id = lk_Scan[:id]
                
                lk_Proteins[lk_Scan[:protein]][:peptides][ls_Peptide] ||= Hash.new
                lk_Proteins[lk_Scan[:protein]][:peptides][ls_Peptide][:ids] ||= Hash.new
                lk_Proteins[lk_Scan[:protein]][:peptides][ls_Peptide][:ids][ls_Id] ||= 0
                lk_Proteins[lk_Scan[:protein]][:peptides][ls_Peptide][:ids][ls_Id] += 1
                lk_Proteins[lk_Scan[:protein]][:peptides][ls_Peptide][:starPeptides] ||= Set.new
                lk_Proteins[lk_Scan[:protein]][:peptides][ls_Peptide][:starPeptides] |= lk_Scan[:starPeptides]
            end
            # inject zero spectral counts where there's nothing else
            lk_Proteins.keys.each do |ls_Protein|
                lk_Proteins[ls_Protein][:peptides].keys.each do |ls_Peptide|
                    ak_Ids.each do |ls_Id|
                        lk_Proteins[ls_Protein][:peptides][ls_Peptide][:ids][ls_Id] = 0 unless lk_Proteins[ls_Protein][:peptides][ls_Peptide][:ids].include?(ls_Id)
                    end
                end
            end
            return lk_Proteins
        end

        if @output[:csvReport]
            File::open(@output[:csvReport], 'w') do |lk_Out|
                lk_Proteins = buildProteinTable(lk_ScanHash, lk_Ids, :modifiedOnly => @param[:modifiedProteinsOnly])
                lk_Out.puts "Protein,Peptide,Modifications,phospho count," + lk_Ids.join(',')
                lk_Proteins.keys.each do |ls_Protein|
                    #lk_PeptideKeys = lk_Proteins[ls_Protein][:peptides].keys.sort { |x, y| lk_Proteins[ls_Protein][:peptides][y][:diff] <=> lk_Proteins[ls_Protein][:peptides][x][:diff] }
                    lk_PeptideKeys = lk_Proteins[ls_Protein][:peptides].keys
                    lk_PeptideKeys.each do |ls_Peptide|
                        lk_Out.puts "\"#{ls_Protein}\",\"#{ls_Peptide}\",,," + lk_Ids.collect { |x| lk_Proteins[ls_Protein][:peptides][ls_Peptide][:ids][x] }.join(',')
                        lk_Proteins[ls_Protein][:peptides][ls_Peptide][:starPeptides].each do |ls_StarPeptide|
                            lk_Out.puts "\"#{ls_Protein}\",\"#{ls_Peptide}\",#{ls_StarPeptide},#{ls_StarPeptide.count('*')}," + lk_Ids.collect { |x| '' }.join(',')
                        end
                    end
                end
            end
        end
    end
end

lk_Object = CompareSequestCsv.new()
