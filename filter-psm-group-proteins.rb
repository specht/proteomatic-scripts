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
require 'include/ruby/ext/fastercsv'
require 'include/ruby/misc'
require 'set'
require 'yaml'

class FilterPsmGroupProteins < ProteomaticScript
	def run()
        print 'Loading PSM...'
        proteins = Hash.new
        @input[:omssaResults].each do |path|
            results = loadPsm(path, :silent => true)
            results[:peptideHash].each do |peptide, info|
                info[:proteins].keys.each do |protein|
                    proteins[protein] ||= Set.new
                    proteins[protein] << peptide
                end
            end
        end
        puts 'done.'
        tempPath = tempFilename('filter-psm-group-proteins-')
        File::open(tempPath, 'w') do |f|
            allProteins = proteins.keys.to_a
            allPeptidesSet = Set.new
            proteins.values.each do |p|
                allPeptidesSet |= p
            end
            allPeptides = allPeptidesSet.to_a
            peptideIndex = Hash.new
            allPeptides.each_with_index do |peptide, i|
                peptideIndex[peptide] = i
            end
            info = Hash.new
            info['proteins'] = allProteins
            info['peptides'] = allPeptides
            info['peptidesForProtein'] = Hash.new
            allProteins.each_with_index do |protein, proteinIndex|
                proteins[protein].each do |peptide|
                    info['peptidesForProtein'][proteinIndex] ||= Array.new
                    info['peptidesForProtein'][proteinIndex] << peptideIndex[peptide]
                end
            end
            f.puts info.to_yaml
        end
        command = ExternalTools::binaryPath('ptb.groupproteins')
        command += " --output \"#{@output[:proteinGroups]}\" \"#{tempPath}\""
        runCommand(command, true)
	end
end

lk_Object = FilterPsmGroupProteins.new
