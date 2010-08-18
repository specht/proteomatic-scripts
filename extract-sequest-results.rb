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
require 'include/ruby/evaluate-omssa-helper'
require 'include/ruby/externaltools'
require 'include/ruby/fasta'
require 'include/ruby/formats'
require 'include/ruby/misc'
require 'bigdecimal'
require 'fileutils'
require 'yaml'


class ExtractSequestResults < ProteomaticScript
    def run()
        # get peptides from PSM list
        ls_Protein = nil
        lk_ForbiddenScanIds = Set.new
        results = Hash.new
        results[:proteins] = Hash.new
        results[:peptideHash] = Hash.new
        File::open(@input[:psmFile].first, 'r') do |lk_File|
            lk_File.each_line do |ls_Line|
                lk_Line = ls_Line.parse_csv
                if (lk_Line[0] && (!lk_Line[0].empty?))
                    # here comes a protein
                    ls_Protein = lk_Line[1].strip
                    results[:proteins][ls_Protein] ||= Set.new
                    next
                end
                if (ls_Protein && lk_Line[2])
                    # here comes a peptide
                    ls_ScanId = lk_Line[1]
                    next if lk_ForbiddenScanIds.include?(ls_ScanId)
                    if lk_Line[2].split('.').size != 3
                        puts "Error: Expecting K.PEPTIDER.A style peptides in SEQUEST results."
                        exit 1
                    end
                    ls_Peptide = lk_Line[2].split('.')[1].strip
                    ls_CleanPeptide = ls_Peptide.gsub(/[^A-Za-z]/, '')
                    results[:proteins][ls_Protein] << ls_CleanPeptide
                    results[:peptideHash][ls_CleanPeptide] ||= Hash.new
                    results[:peptideHash][ls_CleanPeptide][:mods] ||= Hash.new
                    if ls_Peptide != ls_CleanPeptide
                        results[:peptideHash][ls_CleanPeptide][:mods][ls_Peptide] = true
                    end
#                     if lk_ScanHash.include?(ls_ScanId)
#                         # scan already there
#                         if (lk_ScanHash[ls_ScanId][:cleanPeptide] != ls_CleanPeptide)
#                             #puts "ignoring ambiguous match in #{File::basename(ls_Path)}, scan id #{ls_ScanId.split('/').last}, #{lk_ScanHash[ls_ScanId][:cleanPeptide]} / #{ls_CleanPeptide}"
#                             lk_ForbiddenScanIds.add(ls_ScanId)
#                             lk_ScanHash.delete(ls_ScanId)
#                         end
#                     end
#                     unless lk_ForbiddenScanIds.include?(ls_ScanId)
#                         lk_ScanHash[ls_ScanId] ||= {:cleanPeptide => ls_CleanPeptide, :protein => ls_Protein, :mods => Set.new, :id => ls_Id }
#                         ls_ModPeptide = ls_Peptide.dup
#                         while (ls_ModPeptide =~ /[^A-Za-z]/)
#                             index = ls_ModPeptide.index(/[^A-Za-z]/)
#                             ls_ModPeptide[index - 1, 1] = ls_ModPeptide[index - 1, 1].downcase
#                             ls_ModPeptide.sub!(/[^A-Za-z]/, '')
#                         end
#                         lk_ScanHash[ls_ScanId][:mods].add(ls_ModPeptide)
#                     end
                end
            end
        end
        allProteins = results[:proteins].keys.reject do |x|
            results[:proteins][x].size < @param[:distinctPeptides]
        end
        modPeptides = results[:peptideHash].keys.reject do |x|
            results[:peptideHash][x][:mods].empty?
        end
        if @output[:allPeptides]
            File::open(@output[:allPeptides], 'w') do |f|
                f.puts results[:peptideHash].keys.to_a.sort.join("\n")
            end
        end
        if @output[:modPeptides]
            File::open(@output[:modPeptides], 'w') do |f|
                f.puts modPeptides.sort.join("\n")
            end
        end
        if @output[:allProteins]
            File::open(@output[:allProteins], 'w') do |f|
                f.puts allProteins.to_a.sort.join("\n")
            end
        end
        if @output[:modProteins]
            File::open(@output[:modProteins], 'w') do |f|
                modPeptidesSet = Set.new(modPeptides)
                allModProteins = allProteins.reject do |x|
                    someModified = false
                    results[:proteins][x].each do |x|
                        someModified = true if modPeptidesSet.include?(x)
                    end
                    !someModified
                end
                f.puts allModProteins.to_a.sort.join("\n")
            end
        end
    end
end

lk_Object = ExtractSequestResults.new
