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
require './include/ruby/proteomics-knowledge'
require 'yaml'
require 'set'


class CrossLinkMassCalc < ProteomaticScript
    def fragmentMasses(peptide, cutIndex)
        nTerm = peptide[0, cutIndex]
        cTerm = peptide[cutIndex, peptide.size - cutIndex]
        if cutIndex == peptide.size
            return peptideMass(nTerm), peptideMass(cTerm)
        else
            return peptideMass(nTerm) - @waterMass, peptideMass(cTerm)
        end
    end
    
    def fragmentTitles(peptide, cutIndex)
        nTerm = peptide[0, cutIndex]
        cTerm = peptide[cutIndex, peptide.size - cutIndex]
        return cutIndex == peptide.size ? "(complete)" : "b#{cutIndex}", 
               cutIndex == 0 ? "(complete)" : "y#{peptide.size - cutIndex}"
    end
    
    def run()
        @hydrogenMass = $proteomicsKnowledge[:isotopes]['H'][:default][:monoisotopicmass]
        @oxygenMass = $proteomicsKnowledge[:isotopes]['O'][:default][:monoisotopicmass]
        @waterMass = @hydrogenMass * 2.0 + @oxygenMass
        crossLinkerMassShift = @param[:crossLinkerMassShift].to_f
        peptides = [@param[:peptideA], @param[:peptideB]]
        linkIndices = [[], []]
        peptides.each_with_index do |peptide, i|
            lastIndex = -1
            while (lastIndex = peptide.index('K', lastIndex + 1))
                linkIndices[i] << lastIndex
            end
        end

        # DSS is C8H10O2 (138.068080)
        
        # determine precursor mass
        precursorMass = peptideMass(peptides[0]) + peptideMass(peptides[1]) + crossLinkerMassShift
        cutIndices = [(0..peptides[0].size).to_a, (0..peptides[1].size).to_a]
        allMz = Array.new
        # determine all possible crosslink combinations
        linkIndices[0].each do |l0|
            linkIndices[1].each do |l1|
                l = [l0, l1]
                combinationKey = "#{peptides[0]}-#{peptides[1]}-a#{l0 + 1}-b#{l1 + 1}"
                puts combinationKey
                (@param[:minCharge]..@param[:maxCharge]).each do |charge|
                    precursorMz = (precursorMass + $proteomicsKnowledge[:isotopes]['H'][:default][:monoisotopicmass] * charge) / charge
                    # calculate single peptide + crosslink masses
                    # calculate crosslinked / dangling masses
                    cutIndices[0].each do |c0|
                        cutIndices[1].each do |c1|
                            c = [c0, c1]
                            # linkedMass is the fragment containing the crosslinker
                            danglingMasses = [0.0, 0.0]
                            title = ['', '']
                            linkedMass = crossLinkerMassShift
                            linkedTitle = []
                            (0..1).each do |x|
                                masses = fragmentMasses(peptides[x], c[x])
                                titles = fragmentTitles(peptides[x], c[x])
                                if (c[x] > l[x])
                                    # crosslinker is on the N-terminal side
                                    linkedMass += masses[0]
                                    danglingMasses[x] = masses[1]
                                    title[x] = titles[1]
                                    linkedTitle << "#{x == 0 ? 'A' : 'B'} #{titles[0]}"
                                else
                                    danglingMasses[x] = masses[0]
                                    linkedMass += masses[1]
                                    title[x] = titles[0]
                                    linkedTitle << "#{x == 0 ? 'A' : 'B'} #{titles[1]}"
                                end
                                allMz << [(danglingMasses[x] + @hydrogenMass * charge) / charge, "#{combinationKey} / dangling #{x == 0 ? 'A' : 'B'} #{title[x]} (#{charge}+)"] if title[x][-1, 1] != '0'
                            end
                            allMz << [(linkedMass + @hydrogenMass * charge) / charge, "#{combinationKey} / crosslinked #{linkedTitle.join(', ')} (#{charge}+)"]
                        end
                    end
                end
            end
        end
        puts allMz.sort { |a, b| a[0] <=> b[0] }.collect { |x| sprintf('%9.4f', x[0]) + ': ' + x[1] }.uniq.join("\n")
    end
end

script = CrossLinkMassCalc.new
