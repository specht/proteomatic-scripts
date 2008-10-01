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

require 'include/proteomatic'
require 'set'


def wrap(as_String, ai_Width = 70)
	i = ai_Width
	ls_Result = as_String.dup
	while (i < ls_Result.size)
		ls_Result.insert(i, "\n")
		i += ai_Width + 1
	end
	return ls_Result
end


class CheckFasta < ProteomaticScript
	def run()
		if (@output[:nrEntries] || @output[:rEntries]) && (@input[:databases].size > 1)
			puts "Error: only one FASTA database may be specified "
			exit 1
		end
		@input[:databases].each do |ls_Path|
			puts "Checking #{File::basename(ls_Path)}..."
			lk_ProteinKeys = Set.new
			lk_DuplicateProteinKeys = Hash.new
			lk_IdsForProtein = Hash.new
			ls_CurrentId = ''
			ls_CurrentProtein = ''
			li_TotalEntryCount = 0
			File::open(ls_Path).each do |ls_Line|
				ls_Line.strip!
				if (ls_Line[0, 1] == '>')
					li_TotalEntryCount += 1
					unless ls_CurrentProtein.empty?
						# check protein
						lk_IdsForProtein[ls_CurrentProtein] ||= Set.new
						lk_IdsForProtein[ls_CurrentProtein].add(ls_CurrentId)
					end
					# we have an id line
					ls_Line.slice!(0, 1)
					ls_CurrentId = ls_Line
					if (lk_ProteinKeys.include?(ls_CurrentId))
						lk_DuplicateProteinKeys[ls_CurrentId] ||= 1
						lk_DuplicateProteinKeys[ls_CurrentId] += 1
					end
					lk_ProteinKeys.add(ls_CurrentId)
					ls_CurrentProtein = ''
				else
					ls_CurrentProtein += ls_Line
				end
			end
			unless ls_CurrentProtein.empty?
				# check protein
				lk_IdsForProtein[ls_CurrentProtein] ||= Set.new
				lk_IdsForProtein[ls_CurrentProtein].add(ls_CurrentId)
			end
			
			lk_DuplicateProteins = Hash.new
			lk_IdsForProtein.keys.each do |ls_Protein|
				next if lk_IdsForProtein[ls_Protein].size == 1
				lk_DuplicateProteins[ls_Protein] = lk_IdsForProtein[ls_Protein]
			end
			
			puts "Found #{li_TotalEntryCount} entries."
			lb_Error = false
			unless (lk_DuplicateProteinKeys.empty?)
				li_Count = 0
				lk_DuplicateProteinKeys.each { |a, b| li_Count += b }
				puts "Problem: There are #{lk_DuplicateProteinKeys.size} distinct ids which appear multiple times (total #{li_Count})."
				lb_Error = true
				unless lk_DuplicateProteinKeys.empty?
					puts 'Duplicate id lines'
					puts '=================='
					puts
					puts 'The following id lines appear more than once:'
					puts lk_DuplicateProteinKeys.to_a.join("\n")
					puts 'ATTENTION: To make sure that no entries are lost when fixing the database, please fix all duplicate id lines manually before attempting repair.'
					puts
				end
			end
			unless (lk_DuplicateProteins.empty?)
				li_Count = 0
				lk_DuplicateProteins.each { |a, b| li_Count += b.size }
				puts "Problem: There are #{lk_DuplicateProteins.size} distinct proteins which appear multiple times (total #{li_Count})."
				lb_Error = true
			end
			unless lb_Error
				puts "All is well."
			end
			if @output[:nrEntries]
				puts 'Writing non-redundant entries...'
				File::open(@output[:nrEntries], 'w') do |lk_Out|
					ls_CurrentKey = ''
					ls_CurrentProtein = ''
					File::open(ls_Path).each do |ls_Line|
						ls_Line.strip!
						if (ls_Line[0, 1] == '>')
							unless ls_CurrentProtein.empty?
								# handle protein
								unless lk_DuplicateProteinKeys.include?(ls_CurrentKey) || lk_DuplicateProteins.include?(ls_CurrentProtein)
									lk_Out.puts '>' + ls_CurrentKey
									lk_Out.puts wrap(ls_CurrentProtein)
								end
							end
							# we have an id line
							ls_Line.slice!(0, 1)
							ls_CurrentProtein = ''
							ls_CurrentKey = ls_Line
						else
							ls_CurrentProtein += ls_Line
						end
					end
					unless ls_CurrentProtein.empty?
						# handle protein
						unless lk_DuplicateProteinKeys.include?(ls_CurrentKey) || lk_DuplicateProteins.include?(ls_CurrentProtein)
							lk_Out.puts '>' + ls_CurrentKey
							lk_Out.puts wrap(ls_CurrentProtein)
						end
					end
				end
			end
			if @output[:rEntries]
				puts 'Writing fixed redundant entries...'
				File::open(@output[:rEntries], 'w') do |lk_Out|
					unless lk_DuplicateProteins.empty?
						lk_DuplicateProteins.each do |a, b|
							lk_Keys = b.to_a
							ls_MergedKey = lk_Keys.first
							(0...lk_Keys.size).each do |i|
								next if i == 0
								ls_Key = lk_Keys[i]
								lk_Key = ls_Key.split(' ')
								lk_Key.reject! { |x| ls_MergedKey.include?(x) }
								ls_MergedKey += " aka #{lk_Key.join(' ')}"
							end
							lk_Out.puts ">#{ls_MergedKey}"
							lk_Out.puts wrap(a)
						end
					end
				end
			end
		end
	end
end

lk_Object = CheckFasta.new
