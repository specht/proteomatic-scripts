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

require 'yaml'

lk_Lines = File::read('/home/michael/Augustus/gpf-alignments.gff')
li_Nucleotides = 0
ls_CurrentGroup = ''
lk_Lines.each do |ls_Line|
	ls_Line.strip!
	lk_Line = ls_Line.split("\t")
	if (lk_Line[3].to_i > lk_Line[4].to_i)
		puts "Error in #{ls_Line}."
	end
	if (lk_Line[4].to_i - lk_Line[3].to_i + 1 < 4)
		puts "Error in #{ls_Line}."
	end
	ls_Group = lk_Line[8].split(';')[2].sub('grp=', '')
	if (ls_Group != ls_CurrentGroup)
		li_Nucleotides = 0
		ls_CurrentGroup = ls_Group
	end
	li_Frame = lk_Line[7].to_i
	if (lk_Line[2] == 'CDS')
#		if (li_Frame != (3 - (li_Nucleotides % 3)) % 3)
#			puts "Frame error in #{ls_Line}."
#		end
		li_Nucleotides += lk_Line[4].to_i - lk_Line[3].to_i + 1
	end
	#puts lk_Line.to_yaml
	#exit
end
