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

class AnalyzePsm < ProteomaticScript
	def run()
		lk_GeneModels = Hash.new
		@input[:geneModel].each do |ls_Path|
			File.open(ls_Path, 'r') do |lk_File|
				ls_Key = ''
				ls_Protein = ''
				lk_File.each do |ls_Line|
					ls_Line.strip!
					if (ls_Line[0, 1] == '>')
						lk_GeneModels[ls_Key] = ls_Protein unless (ls_Key.empty? || ls_Protein.empty?)
						ls_Key = ls_Line[1, ls_Line.length - 1].strip
						ls_Protein = ''
					else
						ls_Protein += ls_Line
					end
				end
				lk_GeneModels[ls_Key] = ls_Protein unless (ls_Key.empty? || ls_Protein.empty?)
			end
		end
		
		if @output[:analyzedPsm]
			File.open(@output[:analyzedPsm], 'w') do |lk_Out|
				ls_Header = ''
				File.open(@input[:omssaResults].first, 'r') { |lk_File| ls_Header = lk_File.readline.strip }
				lk_Header = ls_Header.split(',').collect { |x| x.strip.downcase.gsub('-', '').gsub(' ', '').gsub('/', '') }
				lk_HeaderIndex = Hash.new
				lk_Header.each { |x| lk_HeaderIndex[x] = lk_Header.index(x) }
				lk_Out.puts ls_Header + ',ppm,left,right'
				@input[:omssaResults].each do |ls_Path|
					File.open(ls_Path, 'r') do |lk_In|
						lk_In.readline
						lk_In.each do |ls_Line|
							lk_Line = ls_Line.parse_csv()
							ls_Scan = lk_Line[lk_HeaderIndex['filenameid']]
							lk_ScanParts = ls_Scan.split('.')
							ls_Spot = lk_ScanParts.slice(0, lk_ScanParts.size - 3).join('.')
							lf_E = BigDecimal.new(lk_Line[lk_HeaderIndex['evalue']])
							ls_DefLine = lk_Line[lk_HeaderIndex['defline']].strip
							lf_Mass = lk_Line[lk_HeaderIndex['mass']].to_f
							lf_TheoMass = lk_Line[lk_HeaderIndex['theomass']].to_f
							li_Start = lk_Line[lk_HeaderIndex['start']].to_i
							li_Stop = lk_Line[lk_HeaderIndex['stop']].to_i
							ls_Peptide = lk_Line[lk_HeaderIndex['peptide']]
							
							# derived values
							lf_ThisPpm = ((lf_Mass - lf_TheoMass).abs / lf_Mass) * 1000000.0
							ls_Left = ''
							ls_Right = ''
							ls_Left = lk_GeneModels[ls_DefLine][li_Start - 2, 1] if li_Start > 1
							ls_Right = lk_GeneModels[ls_DefLine][li_Stop, 1] if li_Stop < lk_GeneModels[ls_DefLine].length
							
							next if lf_ThisPpm > 5.0
							next if ls_Left == 'K' || ls_Left == 'R'
							next if li_Stop > 100
							next if lf_E >= 1e-4
							
							lk_Out.print ls_Line.strip
							lk_Out.print ",#{sprintf('%1.4f', lf_ThisPpm)},#{ls_Left},#{ls_Right}"
							lk_Out.puts
						end
					end
				end
			end
		end
	end
end

lk_Object = AnalyzePsm.new
