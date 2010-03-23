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
require 'include/ruby/evaluate-omssa-helper'
require 'include/ruby/ext/fastercsv'
require 'include/ruby/misc'
require 'set'
require 'yaml'

class GroupProteins < ProteomaticScript
    def run()
        peptideHash = Hash.new
        allProteins = Set.new
        @input[:omssaResults].each do |path|
            results = loadPsm(path)
            results[:peptideHash].each_pair do |peptide, info|
                peptideHash[peptide] ||= Set.new
                thisProteins = Set.new(info[:proteins].keys)
                peptideHash[peptide] |= thisProteins
                allProteins |= thisProteins
            end
        end

        allProteinsList = allProteins.to_a.sort
        proteinIndex = Hash.new
        allProteinsList.each do |protein|
            index = proteinIndex.size
            proteinIndex[protein] = index
        end

        allPeptidesList = peptideHash.keys.sort
        peptideIndex = Hash.new
        allPeptidesList.each do |peptide|
            index = peptideIndex.size
            peptideIndex[peptide] = index
        end

        peptidesForProtein = Hash.new

        unambiguousPeptides = Set.new
        ambiguousPeptides = Set.new
        allPeptides = Set.new

        peptideHash.each_pair do |peptide, proteins|
            allPeptides << peptide
            if proteins.size == 1
                unambiguousPeptides << peptide
            else
                ambiguousPeptides << peptide
            end
            proteins.each do |protein|
                peptidesForProtein[protein] ||= Set.new
                peptidesForProtein[protein] << peptide
            end
        end

        edges = Array.new
        peers = Hash.new

        proteinGroups = Array.new
        singletonProteins = Set.new(peptidesForProtein.keys)

        tempFile = tempFilename('group-proteins-')
        File::open(tempFile, 'w') do |f|
            info = Hash.new
            info['peptides'] = allPeptidesList
            info['proteins'] = allProteinsList
            info['peptidesForProtein'] = Hash.new
            peptidesForProtein.each_pair do |protein, peptides|
                info['peptidesForProtein'][proteinIndex[protein]] = Array.new
                peptides.each do |peptide|
                    info['peptidesForProtein'][proteinIndex[protein]] << peptideIndex[peptide]
                end
            end
            f.puts info.to_yaml
        end
        
        if @output[:groupedProteins]
            system("#{ExternalTools::binaryPath('ptb.groupproteins')} --output \"#{@output[:groupedProteins]}\" \"#{tempFile}\"")
        end
    end
end


lk_Object = GroupProteins.new
