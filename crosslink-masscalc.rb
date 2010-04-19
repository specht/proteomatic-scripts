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
require 'include/ruby/proteomics-knowledge'
require 'yaml'
require 'set'


class CrossLinkMassCalc < ProteomaticScript
	def run()
        crossLinkerMassShift = @param[:crossLinkerMassShift].to_f
        peptides = [@param[:peptideA], @param[:peptideB]]
        cutIndices = [[], []]
        peptides.each_with_index do |peptide, i|
            lastIndex = -1
            while (lastIndex = peptide.index('K', lastIndex + 1))
                cutIndices[i] << lastIndex
            end
        end
        # determine all possible crosslink combinations
        cutIndices[0].each do |c0|
            cutIndices[1].each do |c1|
                combinationKey = "#{peptides[0]}-#{peptides[1]}-a#{c0 + 1}-b#{c1 + 1}"
                puts combinationKey
            end
        end
        precursorMass = peptideMass(peptides[0]) + peptideMass(peptides[1]) + crossLinkerMassShift
        puts "Precursor mass: #{precursorMass}"
        (1..3).each do |charge|
            mz = (precursorMass + $proteomicsKnowledge[:isotopes]['H'][:default][:monoisotopicmass] * charge) / charge
            puts mz
        end
	end
end

lk_Object = CrossLinkMassCalc.new
