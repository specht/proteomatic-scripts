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


class ProteinListToGroups < ProteomaticScript
    def run()
        puts 'Loading protein groups...'
        proteinGroups = YAML::load_file(@input[:proteinGroups].first)
        allProteins = Hash.new
        proteinGroups['proteinGroups'].each_with_index do |list, index|
            list.each do |protein|
                allProteins[protein] ||= []
                allProteins[protein] << index
            end
        end
        unambiguousProteins = allProteins.keys.select { |x| allProteins[x].size == 1 }
        puts "Got #{proteinGroups['proteinGroups'].size} protein groups with #{allProteins.size} (#{unambiguousProteins.size} unambiguous) proteins."
        
        totalCount = 0
        acceptCount = 0
        rejectCount = 0
        
        groupsWritten = Set.new
        
        if @output[:results]
            File::open(@output[:results], 'wb') do |fout|
                @input[:proteinList].each do |path|
                    File::open(path, 'rb') do |f|
                        f.each_line do |protein|
                            totalCount += 1
                            protein.strip!
                            if allProteins.include?(protein) && (allProteins[protein].size > 1)
                                rejectCount += 1
                            else
                                if allProteins.include?(protein)
                                    groupIndex = allProteins[protein].first
                                    groupName = '__group__' + proteinGroups['proteinGroups'][groupIndex].join("\1")
                                    fout.puts groupName unless groupsWritten.include?(groupName)
                                    groupsWritten << groupName
                                else
                                    fout.puts protein
                                end
                                acceptCount += 1
                            end
                        end
                    end
                end
            end
        end
        puts "Shifted #{acceptCount} of #{totalCount} proteins, removed #{rejectCount} proteins because they appeared in multiple groups."
    end
end

lk_Object = ProteinListToGroups.new
