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

# requires target/decoy PSM, strips target_ and decoy_, discards all decoy hits

class FilterPsmByFpr < ProteomaticScript
	def run()
		# first check whether all headers are equal, because in the end they will be merged
		ls_Header = nil
		lk_HeaderMap = nil
		@input[:omssaResults].each do |ls_Path|
			File.open(ls_Path, 'r') do |lk_In|
				# skip header
				ls_Header = lk_In.readline
				lk_ThisHeaderMap = mapCsvHeader(ls_Header)
				if (lk_HeaderMap)
					if (lk_HeaderMap != lk_ThisHeaderMap)
						puts "Error: The header lines of all input files are not identical (#{ls_Path} is different, for example)."
						exit 1
					end
				end
				lk_HeaderMap = lk_ThisHeaderMap
			end
		end

		lk_Result = Hash.new
		lk_Result = cropPsm(@input[:omssaResults], @param[:targetFpr] / 100.0, @param[:scoreThresholdScope] == 'global')
		
		puts 'Warning: No PSM remaining.' if (lk_Result[:scoreThresholds].empty?)
		
		ls_Header = ''
		File.open(@input[:omssaResults].first, 'r') { |lk_File| ls_Header = lk_File.readline.strip }

		if @output[:croppedPsm]
			File.open(@output[:croppedPsm], 'w') do |lk_Out|
				ls_Header += ', scoreThresholdType, targetFpr, actualFpr, scoreThreshold'
				lk_Out.puts(ls_Header)
				@input[:omssaResults].each do |ls_Path|
					File.open(ls_Path, 'r') do |lk_In|
						lk_In.readline
						lk_In.each do |ls_Line|
							lk_Line = ls_Line.parse_csv()
							ls_Spot = '(global)'
							unless @param[:scoreThresholdScope] == 'global'
								ls_Scan = lk_Line[1]
								lk_ScanParts = ls_Scan.split('.')
								ls_Spot = lk_ScanParts.slice(0, lk_ScanParts.size - 3).join('.')
							end
							next unless lk_Result[:actualFpr][ls_Spot]
							lf_E = BigDecimal.new(lk_Line[lk_HeaderMap['evalue']])
							ls_DefLine = lk_Line[lk_HeaderMap['defline']]
							# is it a decoy match? skip it!
							next if ls_DefLine.index('decoy_') == 0
							# is the score too bad? skip it!
							next if lf_E > lk_Result[:scoreThresholds][ls_Spot]

							unless @param[:beStrict] && (lk_Result[:actualFpr][ls_Spot] > @param[:targetFpr] / 100.0)
								lk_Out.print ls_Line.sub('target_', '').strip
								lk_Out.print ", fpr, #{@param[:targetFpr] / 100.0}, #{lk_Result[:actualFpr][ls_Spot]}, #{lk_Result[:scoreThresholds][ls_Spot]}"
								lk_Out.puts
							end
						end
					end
				end
			end
		end
		if @output[:scoreThresholds]
			File.open(@output[:scoreThresholds], 'w') do |lk_Out|
				lk_Hash = Hash.new
				lb_DestroyResults = false
				lk_Hash['actualFpr'] = lk_Result[:actualFpr]
				lk_Hash['targetFpr'] = @param[:targetFpr] / 100.0
				lk_Hash['scoreThresholds'] = Hash.new
				lk_Result[:scoreThresholds].each do |ls_Spot, lk_Threshold|
					lk_Hash['scoreThresholds'][ls_Spot] = lk_Threshold.to_f
				end
				lk_Out.puts lk_Hash.to_yaml
			end
		end
	end
end

lk_Object = FilterPsmByFpr.new
