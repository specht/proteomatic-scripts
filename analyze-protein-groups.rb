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
require './include/ruby/evaluate-omssa-helper'
require './include/ruby/ext/fastercsv'
require './include/ruby/misc'
require 'set'
require 'yaml'

class AnalyzeProteinGroups < ProteomaticScript
    def run()
        proteinGroupsInfo = YAML::load_file(@input[:proteinGroups].first)
        
        proteinGroups = Array.new
        proteinGroupsForProtein = Hash.new
        
        proteinGroupsInfo['proteinGroups'].each do |list|
            combinedName = "__group__" + list.join("\01")
            combinedName = list.first if list.size == 1
            proteinGroups << combinedName
            list.each do |protein|
                proteinGroupsForProtein[protein] ||= Array.new
                proteinGroupsForProtein[protein] << (proteinGroups.size - 1)
            end
        end
        
        puts "Got #{proteinGroupsForProtein.size} proteins in #{proteinGroups.size} protein groups."
        
        nonUniqueProteins = Set.new
        
        proteinGroupsForProtein.each_pair do |protein, entries|
            nonUniqueProteins << protein if entries.size > 1
        end
        
        puts "There are #{nonUniqueProteins.size} non-unique proteins."
        
        if @output[:report]
            File::open(@output[:report], 'w') do |f|
                f.puts nonUniqueProteins.to_a.sort.join("\n")
            end
        end
    end
end

lk_Object = AnalyzeProteinGroups.new
