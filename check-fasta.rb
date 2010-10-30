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

=begin
This script checks for:

duplicate ID lines
duplicate entries
empty ID lines
empty entries
illegal characters in ID lines: "
illegal characters in entries: only amino acid codes are allowed
=end

class CheckFasta < ProteomaticScript
    def run()
        if (@output[:fixedDatabase] || @output[:fixedDatabase]) && (@input[:databases].size > 1)
            puts "Error: only one FASTA database may be specified if you want the repaired database."
            exit 1
        end
        lb_DuplicateIdLines = false
        @input[:databases].each do |ls_Path|
            puts "Checking #{File::basename(ls_Path)}..."
            lk_ProteinKeys = Set.new
            lk_DuplicateProteinKeys = Hash.new
            lk_IdsForProtein = Hash.new
            ls_CurrentId = nil
            ls_CurrentProtein = ''
            li_TotalEntryCount = 0
            lk_EmptyProteins = Set.new
            lk_EmptyIdLines = Array.new
            
            li_CurrentLineIndex = 0
            
            File::open(ls_Path).each do |ls_Line|
                li_CurrentLineIndex += 1
                ls_Line.strip!
                if (ls_Line[0, 1] == '>')
                    li_TotalEntryCount += 1
                    if ls_CurrentId
                        unless ls_CurrentProtein.empty?
                            # check protein
                            lk_IdsForProtein[ls_CurrentProtein] ||= Set.new
                            lk_IdsForProtein[ls_CurrentProtein].add(ls_CurrentId)
                        else
                            lk_EmptyProteins.add(ls_CurrentId)
                        end
                    end
                    # we have an id line
                    ls_Line.slice!(0, 1)
                    ls_CurrentId = ls_Line.strip
                    lk_EmptyIdLines.push(li_CurrentLineIndex) if ls_CurrentId.empty?
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
            if ls_CurrentId
                unless ls_CurrentProtein.empty?
                    # check protein
                    lk_IdsForProtein[ls_CurrentProtein] ||= Set.new
                    lk_IdsForProtein[ls_CurrentProtein].add(ls_CurrentId)
                else
                    lk_EmptyProteins.add(ls_CurrentId)
                end
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
                puts "Problem: There are #{lk_DuplicateProteinKeys.size} distinct id lines which appear multiple times (total #{li_Count}):"
                lb_Error = true
                puts lk_DuplicateProteinKeys.to_a.join("\n")
                lb_DuplicateIdLines = true
            end
            unless (lk_DuplicateProteins.empty?)
                li_Count = 0
                lk_DuplicateProteins.each { |a, b| li_Count += b.size }
                puts "Problem: There are #{lk_DuplicateProteins.size} distinct proteins which appear multiple times (total #{li_Count})."
                lb_Error = true
            end
            unless lk_EmptyIdLines.empty?
                puts "Problem: There are empty id lines at the following line numbers: #{lk_EmptyIdLines.join(', ')}."
                lb_Error = true
            end
            unless (lk_EmptyProteins.empty?)
                puts "Problem: There are #{lk_EmptyProteins.size} empty entries:"
                puts lk_EmptyProteins.to_a.collect { |x| "[#{x}]"}.join("\n")
                lb_Error = true
            end
            unless lb_Error
                puts "All is well."
            end
            if @output[:fixedDatabase]
                lb_Error = false
                if lb_DuplicateIdLines
                    puts 'Error: Cannot fix database while there are duplicate id lines!'
                    lb_Error = true
                end
                unless lk_EmptyIdLines.empty?
                    puts 'Error: Cannot fix database while there are empty id lines!'
                    lb_Error = true
                end
                exit(1) if lb_Error
                
                # lk_LineHash keeps the cropped line counts
                lk_LineHash = Hash.new
 
                puts 'Writing fixed database...'
                File::open(@output[:fixedDatabase], 'w') do |lk_Out|
                    ls_CurrentKey = ''
                    ls_CurrentProtein = ''
                    
                    # write good entries
                    File::open(ls_Path).each do |ls_Line|
                        ls_Line.strip!
                        if (ls_Line[0, 1] == '>')
                            unless ls_CurrentProtein.empty?
                                # handle protein
                                unless lk_DuplicateProteinKeys.include?(ls_CurrentKey) || lk_DuplicateProteins.include?(ls_CurrentProtein)
                                    ls_CroppedKey = ls_CurrentKey[0, @param[:maxIdLength]]
                                    ls_CroppedKey += '[...]' if ls_CroppedKey != ls_CurrentKey
                                    if lk_LineHash.include?(ls_CroppedKey)
                                        lk_LineHash[ls_CroppedKey] += 1
                                        ls_CroppedKey += " (variant #{lk_LineHash[ls_CroppedKey]})"
                                    else
                                        lk_LineHash[ls_CroppedKey] = 1
                                    end
                                    lk_Out.puts '>' + ls_CroppedKey
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
                            ls_CroppedKey = ls_CurrentKey[0, @param[:maxIdLength]]
                            ls_CroppedKey += '[...]' if ls_CroppedKey != ls_CurrentKey
                            if lk_LineHash.include?(ls_CroppedKey)
                                lk_LineHash[ls_CroppedKey] += 1
                                ls_CroppedKey += " (variant #{lk_LineHash[ls_CroppedKey]})"
                            else
                                lk_LineHash[ls_CroppedKey] = 1
                            end
                            lk_Out.puts '>' + ls_CroppedKey
                            lk_Out.puts wrap(ls_CurrentProtein)
                        end
                    end
                    
                    # write merged entries
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
                            unless a.empty?
                                ls_CroppedKey = ls_MergedKey[0, @param[:maxIdLength]]
                                ls_CroppedKey += '[...]' if ls_CroppedKey != ls_MergedKey
                                if lk_LineHash.include?(ls_CroppedKey)
                                    lk_LineHash[ls_CroppedKey] += 1
                                    ls_CroppedKey += " (variant #{lk_LineHash[ls_CroppedKey]})"
                                else
                                    lk_LineHash[ls_CroppedKey] = 1
                                end
                                lk_Out.puts ">#{ls_CroppedKey}"
                                lk_Out.puts wrap(a)
                            end
                        end
                    end
                end
            end
        end
    end
end

lk_Object = CheckFasta.new
