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
require 'include/evaluate-omssa-helper'
require 'include/fastercsv'
require 'include/misc'
require 'set'
require 'yaml'

class CropPsmByMassAccuracy < ProteomaticScript
	def run()
		lf_MaxPpm = @param[:maxPpm]
		lk_Result = Hash.new
		
		ls_Header = ''
		File.open(@input[:omssaResults].first, 'r') { |lk_File| ls_Header = lk_File.readline.strip }

		li_HitCount = 0
		li_SelectCount = 0
		if @output[:croppedPsm]
			File.open(@output[:croppedPsm], 'w') do |lk_Out|
				lk_Out.puts(ls_Header)
				@input[:omssaResults].each do |ls_Path|
					File.open(ls_Path, 'r') do |lk_In|
						lk_In.readline
						lk_In.each do |ls_Line|
							li_HitCount += 1
							lk_Line = ls_Line.parse_csv()
							lf_Mass = lk_Line[4].to_f
							lf_TheoMass = lk_Line[12].to_f
							# is the ppm mass error too bad? skip it!
							# calculate mass error in ppm
							lf_ThisPpm = ((lf_Mass - lf_TheoMass).abs / lf_Mass) * 1000000.0
							# skip this PSM if ppm is not good
							next if lf_ThisPpm > lf_MaxPpm
							li_SelectCount += 1
							
							lk_Out.puts ls_Line
						end
					end
				end
			end
		end
		puts "Discarded #{li_HitCount - li_SelectCount} (#{sprintf('%1.1f', (li_HitCount - li_SelectCount).to_f * 100.0 / li_HitCount)}%) of #{li_HitCount} hits."
	end
end

lk_Object = CropPsmByMassAccuracy.new
