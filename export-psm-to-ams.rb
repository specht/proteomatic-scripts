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

class ExportPsmToAms < ProteomaticScript
	def run()
		@output.each do |ls_InPath, ls_OutPath|
			lk_Result = loadPsm(ls_InPath)
			
			lk_ScanHash = lk_Result[:scanHash]
			lk_PeptideHash = lk_Result[:peptideHash]
			lk_GpfPeptides = lk_Result[:gpfPeptides]
			lk_ModelPeptides = lk_Result[:modelPeptides]
			lk_ProteinIdentifyingModelPeptides = lk_Result[:proteinIdentifyingModelPeptides]
			lk_Proteins = lk_Result[:proteins]
			lk_ScoreThresholds = lk_Result[:scoreThresholds]
			lk_ActualFpr = lk_Result[:actualFpr]
			lk_SpectralCounts = lk_Result[:spectralCounts]
			File.open(ls_OutPath, 'w') do |lk_Out|
				lk_Out.puts "spectrum_id!software!charge!meas_mass!cal_mass!delta_mass!scores!sequence_in!sequence_out!left_fragment!right_fragment!left_pos!right_pos!left_rf!right_rf!tic!database!reference!spectrum!search_string!"
				lk_ScanHash.each do |ls_ScanId, lk_Scan|
					lk_Out.puts "#{ls_ScanId},"
				end
			end
			#puts lk_ScanHash.to_yaml
		end
	end
end

lk_Object = ExportPsmToAms.new
