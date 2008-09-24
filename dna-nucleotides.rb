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

lk_Occurences = Hash.new
li_Length = 1

lk_Scaffolds = Dir['/home/michael/Augustus/flat/*']
lk_Scaffolds.each do |ls_Scaffold|
	puts ls_Scaffold
	ls_Dna = File::read(ls_Scaffold)
	(0...ls_Dna.size - (li_Length - 1)).each do |i|
		ls_Token = ls_Dna[i, li_Length]
		lk_Occurences[ls_Token] ||= 0
		lk_Occurences[ls_Token] += 1
	end
end

puts lk_Occurences.to_yaml
