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

class YamlReport < ProteomaticScript
	
	def dumpGpfInfo(ak_GpfInfo, ak_GpfPeptides)
		lk_Result = Hash.new
		lk_ImmediatePeptides = Set.new
		lk_IntronSplitPeptides = Set.new
		lk_TripletSplitPeptides = Set.new
		lk_EvenSplitPeptides = Set.new
		lk_LostPeptides = Set.new
		ak_GpfPeptides.each do |ls_Peptide|
			ls_Key = ls_Peptide
			lk_Info = ak_GpfInfo[ls_Key]
			if (lk_Info == nil)
				lk_LostPeptides.add(ls_Peptide)
				next
			end
			lk_ImmediatePeptides.add(ls_Peptide) if lk_Info[:immediate] > 0
			lk_IntronSplitPeptides.add(ls_Peptide) if lk_Info[:intronSplit] > 0
			lk_TripletSplitPeptides.add(ls_Peptide) if lk_Info[:tripletSplit] > 0
			lk_EvenSplitPeptides.add(ls_Peptide) if lk_Info[:evenSplit] > 0
		end
		lk_Result[:immediateOnly] = (lk_ImmediatePeptides - lk_IntronSplitPeptides).size
		lk_Result[:immediateAndIntronSplit] = (lk_ImmediatePeptides & lk_IntronSplitPeptides).size
		lk_Result[:intronSplit] = (lk_IntronSplitPeptides - lk_ImmediatePeptides - (lk_TripletSplitPeptides - lk_EvenSplitPeptides)).size
		lk_Result[:intronTripletSplitOnly] = (lk_TripletSplitPeptides - lk_EvenSplitPeptides).to_a
		lk_Result[:lost] = lk_LostPeptides.size
		return lk_Result
	end
	
	def run()
		# merge OMSSA results
		lk_Result = loadPsm(@input[:psmFile].first)
		
		lk_ScanHash = lk_Result[:scanHash]
		lk_PeptideHash = lk_Result[:peptideHash]
		lk_GpfPeptides = lk_Result[:gpfPeptides]
		lk_ModelPeptides = lk_Result[:modelPeptides]
		lk_ProteinIdentifyingModelPeptides = lk_Result[:proteinIdentifyingModelPeptides]
		lk_Proteins = lk_Result[:proteins]
		lk_ScoreThresholds = lk_Result[:scoreThresholds]
		lk_ActualFpr = lk_Result[:actualFpr]
		lk_SpectralCounts = lk_Result[:spectralCounts]
		
		lk_ProteinsBySpectralCount = lk_Proteins.keys.sort { |a, b| lk_SpectralCounts[:proteins][b][:total] <=> lk_SpectralCounts[:proteins][a][:total]}
		lk_AmbiguousPeptides = (lk_ModelPeptides - lk_ProteinIdentifyingModelPeptides).to_a.sort! do |x, y|
			lk_PeptideHash[x][:scans].size == lk_PeptideHash[y][:scans].size ? x <=> y : lk_PeptideHash[y][:scans].size <=> lk_PeptideHash[x][:scans].size
		end

		lk_Info = Hash.new
		lk_Info[:peptides] = lk_PeptideHash.size
		lk_Info[:proteins] = lk_Proteins.size
		lk_Info[:modelPeptidesOnly] = (lk_ModelPeptides - lk_GpfPeptides).size
		lk_Info[:modelAndGpfPeptides] = (lk_ModelPeptides & lk_GpfPeptides).size
		lk_Info[:gpfPeptidesOnly] = (lk_GpfPeptides - lk_ModelPeptides).size
		
		lk_Info[:safeProteins] = lk_Proteins.keys.select do |ls_Protein|
			li_DistinctPeptideCount = lk_Proteins[ls_Protein].size
			li_GpfPeptideCount = 0
			lk_Proteins[ls_Protein].each do |ls_Peptide|
				li_GpfPeptideCount += 1 if lk_PeptideHash[ls_Peptide][:found].include?(:gpf)
			end
			(li_DistinctPeptideCount >= 2) || (li_GpfPeptideCount >= 1)
		end.size

		lk_Info[:gpfSupportedProteins] = lk_Proteins.keys.select do |ls_Protein|
			li_GpfPeptideCount = 0
			lk_Proteins[ls_Protein].each do |ls_Peptide|
				li_GpfPeptideCount += 1 if lk_PeptideHash[ls_Peptide][:found].include?(:gpf)
			end
			(li_GpfPeptideCount >= 1)
		end.size
		
		lk_Info[:safeProteinsBeforeGpfWasBorn] = lk_Proteins.keys.select do |ls_Protein|
			(lk_Proteins[ls_Protein].size >= 2)
		end.size
		
		lk_GpfInfo = YAML::load_file('/home/michael/mia/all-gpf-again-hits-classified.yaml')
		lk_Info[:gpfInfo] = Hash.new
		lk_Info[:gpfInfo][:all] = dumpGpfInfo(lk_GpfInfo, lk_GpfPeptides.to_a)
		lk_Info[:gpfInfo][:gpfOnly] =  dumpGpfInfo(lk_GpfInfo, (lk_GpfPeptides - lk_ModelPeptides).to_a)
		lk_Info[:gpfInfo][:modelsAndGpf] = dumpGpfInfo(lk_GpfInfo, (lk_ModelPeptides & lk_GpfPeptides).to_a)
		if @output[:yamlReport]
			File.open(@output[:yamlReport], 'w') do |lk_Out|
				lk_Out.puts lk_Info.to_yaml
			end
		end
	end
end

lk_Object = YamlReport.new
