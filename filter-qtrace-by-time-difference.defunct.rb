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
require 'include/ext/fastercsv'
require 'include/misc'


class FilterQTraceByTimeDifference < ProteomaticScript
	def run()
		if @output[:filteredResults]
			File::open(@output[:filteredResults], 'w') do |lk_Out|
				File::open(@input[:qTraceResults].first, 'r') do |f|
					ls_Header = f.readline
					lk_Header = mapCsvHeader(ls_Header)
					f.each_line do |ls_Line|
						lf_TimeDifference = ls_Line.parse_csv()[lk_Header['timedifference']].to_f
						lk_Out.puts ls_Line if lf_TimeDifference <= @param[:maxTimeDifference]
					end
				end
			end
		end
	end
end

lk_Object = FilterQTraceByTimeDifference.new

