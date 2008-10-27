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

require 'bigdecimal'

def evaluateFiles(ak_Files, af_TargetFpr)
	lk_ScanHash = Hash.new
	#MT_HydACPAN_25_020507:
	#  MT_HydACPAN_25_020507.1058.1058.2.dta:
	#    :e: 3.88761e-07
	#    :peptides:
	#      NLLAALNHEETR: true
	#    :deflines:
	#    - target_proteins.finalModelsV2.fasta;171789
	#    - target_proteins.frozen_GeneCatalog_2007_09_13.fasta;jgi|Chlre3|194475
	#    - target_gpf-peptides.fasta;NLLAALNHEETR
	#    :mods:
	#    - { :peptide: 'NLLaALNHEETR', :description: ['crazy mod at 4']}
	#    (added later:)
	#    :decoy: false
	
	#puts "Evaluating #{ak_Files.collect { |x| File::basename(x) }.join(', ')}..."
	
	ak_Files.each do |ls_Filename|
		ls_Spot = File::basename(ls_Filename).split('.').first
		lk_File = File.open(ls_Filename, 'r')
		
		# skip header
		lk_File.readline
		
		lk_File.each do |ls_Line|
			lk_Line = ls_Line.parse_csv()
			ls_Scan = lk_Line[1]
			ls_OriginalPeptide = lk_Line[2]
			ls_Peptide = ls_OriginalPeptide.upcase
			lf_E = BigDecimal.new(lk_Line[3])
			ls_DefLine = lk_Line[9]
			lk_Mods = Array.new
			ls_Mods = lk_Line[10]
			lk_Mods = ls_Mods.split(',').collect { |x| x.strip } unless (!ls_Mods) || ls_Mods.empty?
			lf_Mass = lk_Line[4]
			li_Charge = lk_Line[11].to_i
			
			# correct charge in scan name (because when there are multiple charges,
			# only one version of the spectrum may have been sent to OMSSA, because
			# it obviously doens't have to believe the input file, and in that case
			# the charge in the dta filename must be corrected)
			lk_ScanParts = ls_Scan.split('.')
			lk_ScanParts[3] = li_Charge.to_s
			ls_Scan = lk_ScanParts.join('.')
			ls_Spot = lk_ScanParts.first
			ls_Spot = 'all'
			lk_ScanHash[ls_Spot] ||= Hash.new
			
			lk_ScanHash[ls_Spot][ls_Scan] = Hash.new if !lk_ScanHash[ls_Spot].has_key?(ls_Scan)
			if (!lk_ScanHash[ls_Spot][ls_Scan].has_key?(:e) || lf_E < lk_ScanHash[ls_Spot][ls_Scan][:e])
				# clear scan hash
				lk_ScanHash[ls_Spot][ls_Scan][:peptides] = {ls_Peptide => lf_Mass}
				lk_ScanHash[ls_Spot][ls_Scan][:deflines] = [ls_DefLine]
				lk_ScanHash[ls_Spot][ls_Scan][:e] = lf_E;
				lk_ScanHash[ls_Spot][ls_Scan][:mods] = Array.new
				lk_ScanHash[ls_Spot][ls_Scan][:mods].push({:peptide => ls_OriginalPeptide, :description => lk_Mods}) unless lk_Mods.empty?
			elsif (lf_E == lk_ScanHash[ls_Spot][ls_Scan][:e])
				lk_ScanHash[ls_Spot][ls_Scan][:peptides][ls_Peptide] = lf_Mass
				lk_ScanHash[ls_Spot][ls_Scan][:deflines].push(ls_DefLine)
				lk_ScanHash[ls_Spot][ls_Scan][:mods].push({:peptide => ls_OriginalPeptide, :description => lk_Mods}) unless lk_Mods.empty?
			end
		end
	end
	
	# mark decoy scans 
	lk_ScanHash.keys.each do |ls_Spot|
		lk_ScanHash[ls_Spot].keys.each do |ls_Scan|
			lb_Decoy = false
			lk_ScanHash[ls_Spot][ls_Scan][:deflines].each { |ls_DefLine| lb_Decoy = true if ls_DefLine[0, 6] == 'decoy_' }
			lk_ScanHash[ls_Spot][ls_Scan][:decoy] = lb_Decoy
		end
	end
	
	li_TotalScanCount = 0
	lk_GoodScans = Array.new
	
	lk_EThresholds = Hash.new
	lk_ActualFpr = Hash.new
	
	# here is the target-decoy cutoff strategy:
	# we have a target FPR but we do not yet know whether we can achieve a FPR
	# less or equal to that target FPR. So search for the global FPR minimum
	# initially, and if we find a FPR which is <= the target FPR, search for
	# the global maximum FRP which is <= the target FPR
	
	lb_FoundValidFpr = false
	
	# determine e-value cutoff for each spot
	lk_ScanHash.keys.each do |ls_Spot|
		li_TotalScanCount += lk_ScanHash[ls_Spot].size
		# sort scans by e value
		lk_ScansByE = lk_ScanHash[ls_Spot].keys.sort { |a, b| lk_ScanHash[ls_Spot][a][:e] <=> lk_ScanHash[ls_Spot][b][:e] }
		
		li_TotalCount = 0
		li_DecoyCount = 0
		li_CropCount = 0
		lk_ScansByE.each do |ls_Scan|
			#puts lk_ScanHash[ls_Spot][ls_Scan].to_yaml
			li_TotalCount += 1
			li_DecoyCount += 1 if lk_ScanHash[ls_Spot][ls_Scan][:decoy]
			lf_Fpr = li_DecoyCount.to_f * 2.0 / li_TotalCount.to_f * 100.0
			#puts "#{sprintf('%1.2f', lf_Fpr)}\t#{lk_ScanHash[ls_Spot][ls_Scan][:e].to_f}\t#{lk_ScanHash[ls_Spot][ls_Scan][:deflines].first}"
			if (li_DecoyCount > 0)
				if (lb_FoundValidFpr)
					# search for the global maximum FPR that is <= target FPR
					if (lf_Fpr > lk_ActualFpr[ls_Spot])
						lk_ActualFpr[ls_Spot] = lf_Fpr
						li_CropCount = li_TotalCount
					end
				else
					# search for the global minimum FPR
					if ((!lk_ActualFpr[ls_Spot]) || (lf_Fpr < lk_ActualFpr[ls_Spot]))
						lk_ActualFpr[ls_Spot] = lf_Fpr
						li_CropCount = li_TotalCount
						lb_FoundValidFpr = true if (lf_Fpr <= af_TargetFpr)
					end
				end
			end
		end
		
		lk_GoodScans += lk_ScansByE[0, li_CropCount]
		lk_EThresholds[ls_Spot] = lk_ScanHash[ls_Spot][lk_ScansByE[li_CropCount - 1]][:e] if li_CropCount > 0
	end
	
	puts lk_ActualFpr.to_yaml
	
	# chuck spots out of lk_ScanHash
	lk_NewScanHash = Hash.new
	lk_ScanHash.keys.each { |ls_Spot| lk_NewScanHash.merge!(lk_ScanHash[ls_Spot]) }
	lk_ScanHash = lk_NewScanHash
	
	lk_GoodScans.delete_if { |ls_Scan| lk_ScanHash[ls_Scan][:decoy] || lk_ScanHash[ls_Scan][:peptides].size > 1 }
	
	lk_PeptideHash = Hash.new
	#WLQYSEVIHAR:
	#  :scans: [MT_HydACPAN_1_300407.100.100.2, ...]
	#  :spots: (MT_HydACPAN_1_300407) (set)
	#  :found: {gpf, models}
	#  :proteins: {x => true, y => true}
	#  :mods:
	#    WLQYsEVIHAR:
	#      'yada yada':
	#        MT_HydACPAN_1_300407: [MT_HydACPAN_1_300407.100.100.2]
	
	lk_GoodScans.each do |ls_Scan|
		ls_Peptide = lk_ScanHash[ls_Scan][:peptides].keys.first
		if !lk_PeptideHash.has_key?(ls_Peptide)
			lk_PeptideHash[ls_Peptide] = Hash.new 
			lk_PeptideHash[ls_Peptide][:scans] = Array.new
			lk_PeptideHash[ls_Peptide][:spots] = Set.new
			lk_PeptideHash[ls_Peptide][:found] = Hash.new
			lk_PeptideHash[ls_Peptide][:proteins] = Hash.new
			lk_PeptideHash[ls_Peptide][:mods] = Hash.new
		end
		lk_PeptideHash[ls_Peptide][:scans].push(ls_Scan)
		ls_Spot = ls_Scan[0, ls_Scan.index('.')]
		lk_PeptideHash[ls_Peptide][:spots].add(ls_Spot)
		lk_ScanHash[ls_Scan][:mods].each do |lk_Mod|
			lk_PeptideHash[ls_Peptide][:mods][lk_Mod[:peptide]] ||= Hash.new
			ls_Description = lk_Mod[:description].join(', ')
			lk_PeptideHash[ls_Peptide][:mods][lk_Mod[:peptide]][ls_Description] ||= Hash.new
			lk_PeptideHash[ls_Peptide][:mods][lk_Mod[:peptide]][ls_Description][ls_Spot] ||= Array.new
			lk_PeptideHash[ls_Peptide][:mods][lk_Mod[:peptide]][ls_Description][ls_Spot].push(ls_Scan)
		end
		lk_ScanHash[ls_Scan][:deflines].each do |ls_DefLine|
			if (ls_DefLine[0, 12] == 'target_gpf__')
				lk_PeptideHash[ls_Peptide][:found][:gpf] = true 
			else
				lk_PeptideHash[ls_Peptide][:found][:models] = true 
				lk_PeptideHash[ls_Peptide][:proteins][ls_DefLine] = true
			end
		end
	end
	
	
	# sort scans in lk_PeptideHash by e-value
	lk_PeptideHash.keys.each do |ls_Peptide|
		lk_PeptideHash[ls_Peptide][:scans] = lk_PeptideHash[ls_Peptide][:scans].sort { |a, b| lk_ScanHash[a][:e] <=> lk_ScanHash[b][:e] }
	end
	
	lk_GpfPeptides = Set.new
	lk_ModelPeptides = Set.new
	lk_ProteinIdentifyingModelPeptides = Set.new
	
	lk_PeptideHash.keys.each do |ls_Peptide|
		lk_GpfPeptides.add(ls_Peptide) if lk_PeptideHash[ls_Peptide][:found].has_key?(:gpf)
		lk_ModelPeptides.add(ls_Peptide) if lk_PeptideHash[ls_Peptide][:found].has_key?(:models)
		lk_ProteinIdentifyingModelPeptides.add(ls_Peptide) if lk_PeptideHash[ls_Peptide][:proteins].size == 1
	end
	
	lk_Proteins = Hash.new
	lk_ProteinIdentifyingModelPeptides.each do |ls_Peptide|
		ls_Protein = lk_PeptideHash[ls_Peptide][:proteins].keys.first.sub('target_', '')
		if !lk_Proteins.has_key?(ls_Protein)
			lk_Proteins[ls_Protein] = Hash.new
			lk_Proteins[ls_Protein][:spectraCount] = 0
			lk_Proteins[ls_Protein][:peptides] = Hash.new
		end
		lk_Proteins[ls_Protein][:spectraCount] += lk_PeptideHash[ls_Peptide][:scans].size
		lk_Proteins[ls_Protein][:peptides][ls_Peptide] = lk_PeptideHash[ls_Peptide][:scans].size
	end
	
	lk_Result = Hash.new
	
	lk_Result[:goodScans] = lk_GoodScans
	lk_Result[:scanHash] = lk_ScanHash
	lk_Result[:peptideHash] = lk_PeptideHash
	lk_Result[:gpfPeptides] = lk_GpfPeptides
	lk_Result[:modelPeptides] = lk_ModelPeptides
	lk_Result[:proteinIdentifyingModelPeptides] = lk_ProteinIdentifyingModelPeptides
	lk_Result[:proteins] = lk_Proteins
	lk_Result[:eThresholds] = lk_EThresholds
	lk_Result[:actualFpr] = lk_ActualFpr
	
	return lk_Result
end

