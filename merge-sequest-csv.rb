# Copyright (c) 2009 Michael Specht
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
require 'include/evaluate-omssa-helper'
require 'include/ext/fastercsv'
require 'include/misc'
require 'set'
require 'yaml'


class MergeSequestCsv < ProteomaticScript
	def run()
		
		ls_AllHeader = nil
		if @output[:mergedResults]
			@input[:sequestResults].each do |ls_Path|
				File::open(ls_Path, 'r') do |f|
					ls_ThisHeader = f.readline + f.readline
					ls_ThisHeader.strip!
					ls_AllHeader ||= ls_ThisHeader
					if (ls_AllHeader != ls_ThisHeader)
						puts "Error: first two lines must be identical in all input files!"
						exit 1
					end
				end
			end
			File::open(@output[:mergedResults], 'w') do |lk_Out|
				lk_Out.puts ls_AllHeader
				@input[:sequestResults].each do |ls_Path|
					ls_Basename = File::basename(ls_Path).sub('.csv', '')
					File::open(ls_Path, 'r') do |f|
						ls_ThisHeader = f.readline + f.readline
						f.each_line do |line|
							lineArray = line.parse_csv()
							if (!lineArray[0] && (lineArray[1] && (!lineArray[1].empty?)))
								scanId = ls_Basename + '.' + lineArray[1]
								lineArray[1] = scanId
							end
							lk_Out.puts lineArray.to_csv()
						end
					end
				end
			end
		end
	end
end


lk_Object = MergeSequestCsv.new()
