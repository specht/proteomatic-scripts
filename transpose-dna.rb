# Copyright (c) 2007-2010 Michael Specht
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

# this script transposes DNA, OMG!!


class TransposeDna < ProteomaticScript
    def run()
        lk_Nucleotides = {'A' => 'T', 'C' => 'G', 'G' => 'C', 'T' => 'A'}
        ls_Source = @param[:nucleotides].upcase.gsub(/[^CGAT]/, '').reverse.upcase
        ls_Result = ''
        (0...ls_Source.size).each do |i|
            ls_Result += lk_Nucleotides[ls_Source[i, 1]]
        end
        puts ls_Result
    end
end

lk_Object = TransposeDna.new
