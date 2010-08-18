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

require 'include/ruby/proteomatic'

class MergeFasta < ProteomaticScript
    def run()
        lk_Databases = @input[:databases]
        
        # merge all databases
        
        if @output[:merged]
            puts "Merging #{lk_Databases.size} fasta databases..."
        
            File.open(@output[:merged], 'w') do |lk_Out|
                lk_Databases.each do |ls_Filename|
                    ls_Basename = File.basename(ls_Filename)
                    File.open(ls_Filename, 'r') do |lk_File|
                        lk_File.each do |ls_Line|
                            ls_Line.strip!
                            if !ls_Line.empty?
                                lk_Out.puts ls_Line
                            end
                        end
                    end
                end
            end
        end
    end
end

lk_Object = MergeFasta.new
