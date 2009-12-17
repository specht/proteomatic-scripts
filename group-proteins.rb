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

=begin
        peptideHash = Hash.new
        peptideHash = {
            'A' => {:proteins => {'1' => true, '2' => true, '3' => true, '4' => true, '8' => true}},
            'B' => {:proteins => {'1' => true, '3' => true, '4' => true, '8' => true}},
            'C' => {:proteins => {'1' => true, '4' => true, '5' => true, '6' => true, '8' => true}},
            'D' => {:proteins => {'1' => true, '2' => true}},
            'E' => {:proteins => {'5' => true, '6' => true, '7' => true, '8' => true}},
            'F' => {:proteins => {'6' => true, '7' => true}},
            'G' => {:proteins => {'7' => true}}
        }
=end

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

        puts "Peptide yield before protein grouping: #{sprintf('%1.1f', unambiguousPeptides.size * 100.0 / allPeptides.size)}% of #{allPeptides.size} peptides."

        edges = Array.new
        peers = Hash.new

        proteinGroups = Array.new
        singletonProteins = Set.new(peptidesForProtein.keys)

        totalCount = (peptidesForProtein.size * peptidesForProtein.size - peptidesForProtein.size) / 2
        currentCount = 0
        oldPercentage = -1.0
        peptidesForProtein.keys.each do |proteinA|
            peptidesForProtein.keys.each do |proteinB|
                next if proteinA <= proteinB
                percentage = sprintf('%1.1f', currentCount.to_f * 100.0 / totalCount) if currentCount % 1000 == 0
                print "\rAnalyzing protein pairs... #{percentage}% done." if percentage != oldPercentage
                oldPercentage = percentage
                currentCount += 1
                peptidesA = peptidesForProtein[proteinA]
                peptidesB = peptidesForProtein[proteinB]
                if (peptidesA.subset?(peptidesB) || peptidesB.subset?(peptidesA))
                    singletonProteins.delete(proteinA)
                    singletonProteins.delete(proteinB)
                    # proteins A and B belong into a protein group!
                    groupPeptides = peptidesA | peptidesB
                    couldJoin = false
                    proteinGroups.each_index do |i|
                        peptides = proteinGroups[i][:peptides]
                        if peptides.subset?(groupPeptides) || groupPeptides.subset?(peptides)
                            # we found a group we can join
                            proteinGroups[i][:peptides] |= groupPeptides
                            proteinGroups[i][:proteins] << proteinA
                            proteinGroups[i][:proteins] << proteinB
                            couldJoin = true
                            break
                        end
                    end
                    unless couldJoin
                        # start a new protein group
                        proteinGroups << {:peptides => groupPeptides, :proteins => Set.new([proteinA, proteinB])}
                    end
                end
            end
        end
        puts "\rAnalyzing protein pairs... 100.0% done."

        # add ungrouped proteins as single-protein groups
        singletonProteins.each do |protein|
            proteinGroups << {:peptides => Set.new(peptidesForProtein[protein]), :proteins => Set.new([protein])}
        end
        
        # convert protein sets into sorted protein lists, all-comprising ones first
        proteinGroups.each_index do |groupIndex|
            proteins = proteinGroups[groupIndex][:proteins].to_a
            proteins.sort! do |a, b|
                peptidesForProtein[b].size <=> peptidesForProtein[a].size
            end
            proteinGroups[groupIndex][:proteins] = proteins
        end

        puts "There are #{proteinGroups.size} protein groups.\n"

        # determine unique and razor peptides
        groupsForPeptide = Hash.new
        proteinGroups.each_index do |groupIndex|
            group = proteinGroups[groupIndex]
            group[:peptides].each do |peptide|
                groupsForPeptide[peptide] ||= Set.new
                groupsForPeptide[peptide] << groupIndex
            end
        end

        uniquePeptides = Hash.new
        razorPeptides = Hash.new

        groupsForPeptide.each_pair do |peptide, groupSet|
            if groupSet.size == 1
                uniquePeptides[peptide] = groupSet.first 
            else
                # find the protein group with the most peptides
                bestPeptideCount = 0
                bestGroupIndex = nil
                groupSet.each do |groupIndex|
                    peptideCount = proteinGroups[groupIndex][:peptides].size
                    if (peptideCount > bestPeptideCount)
                        bestGroupIndex = groupIndex
                    end
                end
                razorPeptides[peptide] = bestGroupIndex
            end
        end

        puts "Peptide yield after protein grouping: #{sprintf('%1.1f', uniquePeptides.size * 100.0 / allPeptides.size)}% of #{allPeptides.size} peptides."
        
        if @output[:groupedProteins]
            File::open(@output[:groupedProteins], 'w') do |f|
                info = Hash.new
                #info['proteins'] = allProteinsList
                #info['peptides'] = allPeptidesList
                info['proteinGroups'] = Array.new
                proteinGroups.each do |group|
                    info['proteinGroups'] << group[:proteins]
                end
                
                info['peptides'] = Hash.new
                groupsForPeptide.each_pair do |peptide, groupSet|
                    # find the protein group with the most peptides
                    # if there's only one group, it's a unique peptide
                    groupList = groupSet.to_a
                    groupList.sort! do |a, b|
                        proteinGroups[b][:peptides].size <=> proteinGroups[a][:peptides].size
                    end
                    info['peptides'][peptide] = groupList
                end

                f.puts info.to_yaml
            end
        end
        # proteinGroups.each_index do |groupIndex|
        #     groupKey = "group_#{groupIndex}"
        #     puts groupKey
        # end
    end
end


lk_Object = GroupProteins.new
