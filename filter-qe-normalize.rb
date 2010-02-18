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
require 'include/ruby/evaluate-omssa-helper'
require 'include/ruby/ext/fastercsv'
require 'include/ruby/misc'
require 'set'
require 'yaml'


class NormalizeProteinLevels < ProteomaticScript
	def run()
		# test whether QE CSV headers are all the same
		ls_AllHeader = nil
		lk_AllHeader = nil
		@input[:quantitationEvents].each do |ls_InPath|
			File::open(ls_InPath, 'r') do |lk_In|
				ls_Header = lk_In.readline
				lk_Header = Set.new(mapCsvHeader(ls_Header).keys())
				ls_AllHeader ||= ls_Header
				lk_AllHeader = lk_Header
				if lk_Header != lk_AllHeader
					puts "Error: The CSV header was not consistent throughout all quantitation event input files. The offending header line was #{ls_Header}."
					exit 1
				end
			end
		end
		
        puts "Changing amounts from #{@param[:factor]} to 1.0."
		if @output[:results]
			File::open(@output[:results], 'w') do |lk_Out|
				print 'Writing normalized results...'
				li_InCount = 0
				li_OutCount = 0
				lk_Out.puts ls_AllHeader
				@input[:quantitationEvents].each do |ls_InPath|
					File::open(ls_InPath, 'r') do |lk_In|
						ls_Header = lk_In.readline
						lk_Header = mapCsvHeader(ls_Header)
						lk_In.each_line do |ls_Line|
							li_InCount += 1
							lk_Line = ls_Line.parse_csv()
                            lf_AmountHeavy = lk_Line[lk_Header['amountheavy']].to_f
                            lf_AmountHeavy *= @param[:factor]
                            lk_Line[lk_Header['amountheavy']] = lf_AmountHeavy.to_s
                            lk_Out.puts lk_Line.to_csv()
						end
					end
				end
                puts 'done.'
			end
		end
	end
end

lk_Object = NormalizeProteinLevels.new
