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
require 'include/ext/fastercsv'
require 'include/misc'
require 'set'


def cropPsm(ak_Files, af_TargetFpr, ab_DetermineGlobalScoreThreshold, as_TargetPrefix = '__td__target_', as_DecoyPrefix = '__td__decoy_')
	lk_ScanHash = Hash.new
	#MT_HydACPAN_25_020507:
	#  MT_HydACPAN_25_020507.1058.1058.2.dta:
	#    :e: 3.88761e-07
	#    :peptides:
	#      NLLAALNHEETR: 
	#        :measuredMass: 1374.32
	#        :calculatedMass: 1374.31
	#    :deflines:
	#    - target_proteins.finalModelsV2.fasta;171789
	#    - target_proteins.frozen_GeneCatalog_2007_09_13.fasta;jgi|Chlre3|194475
	#    - target_gpf-peptides.fasta;NLLAALNHEETR
	#    :mods:
	#    - { :peptide: 'NLLaALNHEETR', :description: ['crazy mod at 4']}
	#    (added later:)
	#    :decoy: false
	
	#puts "Evaluating #{ak_Files.collect { |x| File::basename(x) }.join(', ')}..."
	
	# read all PSM from all result files in ak_Files, record them in lk_ScanHash
	li_EntryCount = 0
	li_ErrorCount = 0
	ls_ErrorLine = nil
	lk_Warnings = Set.new
	ak_Files.each do |ls_Filename|
		lk_File = File.open(ls_Filename, 'r')
		
		# skip header
		lk_HeaderMap = mapCsvHeader(lk_File.readline)
		li_LineNumber = 1
		
		lk_File.each do |ls_Line|
			li_LineNumber += 1
			lk_Line = Array.new
			begin
				lk_Line = ls_Line.parse_csv()
			rescue StandardError => e
				puts "Something is wrong with line #{li_LineNumber}:"
				puts ls_Line
				puts e
				exit 1
			end
			li_EntryCount += 1
			print "\rReading PSM entries... #{li_EntryCount}" if (li_EntryCount % 1000 == 0)
			lk_Line = ls_Line.parse_csv()
			ls_Scan = lk_Line[lk_HeaderMap['filenameid']]
			ls_OriginalPeptide = lk_Line[lk_HeaderMap['peptide']]
			ls_Peptide = ls_OriginalPeptide.upcase
			lf_E = BigDecimal.new(lk_Line[lk_HeaderMap['evalue']])

			ls_DefLine = lk_Line[lk_HeaderMap['defline']]
			unless (ls_DefLine.index(as_TargetPrefix) == 0) || (ls_DefLine.index(as_DecoyPrefix) == 0)
				unless ls_DefLine.index('__putative__') == 0
					lk_Warnings.add("Warning: There is a PSM which does not come from a target/decoy search in #{ls_Filename}.")
				end
				next
			end
			lk_Mods = Array.new
			ls_Mods = lk_Line[lk_HeaderMap['mods']]
			lk_Mods = ls_Mods.split(',').collect { |x| x.strip } unless (!ls_Mods) || ls_Mods.empty?
			lf_Mass = lk_Line[lk_HeaderMap['mass']]
			lf_TheoMass = lk_Line[lk_HeaderMap['theomass']]
			li_Charge = lk_Line[lk_HeaderMap['charge']].to_i
			
			# correct charge in scan name (because when there are multiple charges,
			# only one version of the spectrum may have been sent to OMSSA, because
			# it obviously doens't have to believe the input file, and in that case
			# the charge in the dta filename must be corrected)
			lk_ScanParts = ls_Scan.split('.')
			# remove trailing .dta if it's there
			lk_ScanParts.slice!(-1, 1) if (lk_ScanParts.last == 'dta')
			begin
				li_TestStartScan = Integer(lk_ScanParts[-3])
				li_TestStopScan = Integer(lk_ScanParts[-2])
				li_TestCharge = Integer(lk_ScanParts[-1])
				if (li_TestCharge < 1 || (li_TestStopScan < li_TestStartScan))
					li_ErrorCount += 1
					ls_ErrorLine = ls_Scan
					next
				end
			rescue StandardError => e
				li_ErrorCount += 1
				next
			end
			lk_ScanParts[-1] = li_Charge.to_s
			ls_Scan = lk_ScanParts.join('.')
			
			# determine spot name from scan name by cutting off start scan,
			# end scan, and charge, but make it (global) if we want a global
			# score threshold
			ls_Spot = '(global)'
			ls_Spot = lk_ScanParts.slice(0, lk_ScanParts.size - 3).join('.') unless ab_DetermineGlobalScoreThreshold
			
			lk_ScanHash[ls_Spot] ||= Hash.new
			lk_ScanHash[ls_Spot][ls_Scan] ||= Hash.new
			if (!lk_ScanHash[ls_Spot][ls_Scan].has_key?(:e) || lf_E < lk_ScanHash[ls_Spot][ls_Scan][:e])
				# clear scan hash
				lk_ScanHash[ls_Spot][ls_Scan][:e] = lf_E;
				lk_ScanHash[ls_Spot][ls_Scan][:decoy] = {(ls_DefLine.index(as_DecoyPrefix) == 0) => true}
			elsif (lf_E == lk_ScanHash[ls_Spot][ls_Scan][:e])
				lk_ScanHash[ls_Spot][ls_Scan][:decoy][(ls_DefLine.index(as_DecoyPrefix) == 0)] = true
			end
		end
	end
	puts "\rReading PSM entries... #{li_EntryCount}."
	unless lk_Warnings.empty?
		puts lk_Warnings.to_a.join("\n")
	end
	if (li_ErrorCount > 0)
		puts "ATTENTION: The scan name was not as expected in #{li_ErrorCount} of #{li_EntryCount} lines, these lines have been ignored."
		puts "The scan name is expected to end with (start scan).(end scan).(charge)."
		puts "The last of these erroneous lines is:"
		puts ls_ErrorLine
	end
	
	lk_EThresholds = Hash.new
	lk_ActualFpr = Hash.new
	
	# here is the target-decoy cutoff strategy:
	# we have a target FPR but we do not yet know whether we can achieve a FPR
	# less or equal to that target FPR. So search for the global FPR minimum
	# initially, and if we find a FPR which is <= the target FPR, search for
	# the global maximum FRP which is <= the target FPR
	
	lk_Spots = lk_ScanHash.keys
	
	# determine e-value cutoff for each spot 
	# (or global but then there's only one (global) 'spot')
	lk_Spots.each do |ls_Spot|
		# sort scans by e value
		lk_LocalScanHash = lk_ScanHash[ls_Spot]
		lb_FoundValidFpr = false
		
		lk_ScansByE = lk_LocalScanHash.keys.sort { |a, b| lk_LocalScanHash[a][:e] <=> lk_LocalScanHash[b][:e] }
		
		li_TotalCount = 0
		li_DecoyCount = 0
		li_CropCount = 0
		lk_ScansByE.each do |ls_Scan|
			li_TotalCount += 1
			li_DecoyCount += 1 if lk_LocalScanHash[ls_Scan][:decoy][true]
			lf_Fpr = li_DecoyCount.to_f * 2.0 / li_TotalCount.to_f
			if (li_DecoyCount > 0)
				if (lb_FoundValidFpr)
					# search for the global maximum FPR that is <= target FPR
					if ((lf_Fpr > lk_ActualFpr[ls_Spot]) && (lf_Fpr <= af_TargetFpr))
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
		
		lk_EThresholds[ls_Spot] = lk_LocalScanHash[lk_ScansByE[li_CropCount - 1]][:e] if li_CropCount > 0
	end
	return {:scoreThresholds => lk_EThresholds, :actualFpr => lk_ActualFpr}
end


def loadPsm(as_Path, ak_Options = {})
	ak_Options[:putativePrefix] ||= '__putative__'
	lk_ScanHash = Hash.new
	#MT_HydACPAN_25_020507.1058.1058.2.dta:
	#  :e: 3.88761e-07
	#  :peptides:
	#    NLLAALNHEETR: 
	#      :measuredMass: 1374.32
	#      :calculatedMass: 1374.31
	#      :charge: 2
	#  :deflines:
	#  - target_proteins.finalModelsV2.fasta;171789
	#  - target_proteins.frozen_GeneCatalog_2007_09_13.fasta;jgi|Chlre3|194475
	#  - target_gpf-peptides.fasta;NLLAALNHEETR
	#  :mods:
	#  - { :peptide: 'NLLaALNHEETR', :description: ['crazy mod at 4']}
	
	#puts "Evaluating #{ak_Files.collect { |x| File::basename(x) }.join(', ')}..."
	
	# read all PSM from all result files in ak_Files, record them in lk_ScanHash
	li_EntryCount = 0
	li_ErrorCount = 0
	ls_ErrorLine = nil
	
	lk_ScoreThreshold = Hash.new
	lk_ActualFpr = Hash.new
	lf_TargetFpr = nil
	lb_HasFpr = false
	lb_GlobalFpr = false
	ls_ScoreThresholdType = nil
	
	# lk_SpectralCounts:
	#   :peptides:
	#     LYDEELQAIAK:
	#       MT_HydACPAN_25_020507: 14
	#       MT_HydACPAN_23_020507: 12
	#       :total: 26
	#   :proteins:
	#     extgeneshsomething:
	#       MT_HydACPAN_25_020507: 2
	#       MT_HydACPAN_23_020507: 6
	#       :total: 8
	lk_SpectralCounts = {:peptides => Hash.new, :proteins => Hash.new }
	lk_PeptideInProtein = Hash.new
	
	File.open(as_Path, 'r') do |lk_File|
		# read header
		ls_Header = lk_File.readline
		lk_HeaderMap = mapCsvHeader(ls_Header)
		lb_FirstLineComing = true
		lb_HasFpr = nil
		lb_HasFixedScoreThreshold = nil
		lb_OldFormatWithoutScoreThresholdType = false
		
		lk_File.each do |ls_Line|
			li_EntryCount += 1
			print "\rReading PSM entries... #{li_EntryCount}" if (li_EntryCount % 1000 == 0) unless ak_Options[:silent]
			lk_Line = ls_Line.parse_csv()
			
			if (lb_FirstLineComing)
				lb_FirstLineComing = false
				
				ls_ScoreThresholdType = lk_Line[lk_HeaderMap['scorethresholdtype']] if (lk_HeaderMap.include?('scorethresholdtype'))
				ls_ScoreThresholdType = ls_ScoreThresholdType.downcase.strip if ls_ScoreThresholdType
				# if no score threshold type is given, but we have targetfpr, 
				# actualfpr, and scorethreshold, make it fpr!
				unless (ls_ScoreThresholdType)
					if (lk_HeaderMap.include?('targetfpr') && lk_HeaderMap.include?('actualfpr') && lk_HeaderMap.include?('ethreshold'))
						# we have an old format here, in which scorethreshold is called ethreshold
						# make it FPR!
						lk_HeaderMap['scorethreshold'] = lk_HeaderMap['ethreshold']
						ls_ScoreThresholdType = 'fpr'
						lb_OldFormatWithoutScoreThresholdType = true
					end
				end
				lb_HasFpr = ls_ScoreThresholdType == 'fpr'
				lb_HasFixedScoreThreshold = ls_ScoreThresholdType == 'min' || ls_ScoreThresholdType == 'max'

				unless ak_Options[:silent]
					print 'Statistical significance: '
					if (lb_HasFpr)
						puts 'FPR (adaptive score threshold).'
					elsif (lb_HasFixedScoreThreshold)
						puts 'fixed score threshold.'
					else
						puts 'none at all!'
					end
				end
			end
			ls_Scan = lk_Line[lk_HeaderMap['filenameid']]
			ls_OriginalPeptide = lk_Line[lk_HeaderMap['peptide']]
			ls_Peptide = ls_OriginalPeptide.upcase
			lf_E = BigDecimal.new(lk_Line[lk_HeaderMap['evalue']])
			ls_DefLine = lk_Line[lk_HeaderMap['defline']]
			lk_Mods = Array.new
			ls_Mods = lk_Line[lk_HeaderMap['mods']]
			lk_Mods = ls_Mods.split(',').collect { |x| x.strip } unless (!ls_Mods) || ls_Mods.empty?
			lb_IsUnmodified = lk_Mods.empty?
			lf_Mass = lk_Line[lk_HeaderMap['mass']]
			lf_TheoMass = lk_Line[lk_HeaderMap['theomass']]
			li_Charge = lk_Line[lk_HeaderMap['charge']].to_i
			li_Start = lk_Line[lk_HeaderMap['start']].to_i
			lf_RetentionTime = nil
			lf_RetentionTime = lk_Line[lk_HeaderMap['retentiontime']].to_f if lk_HeaderMap.include?('retentiontime')

			if (ls_DefLine.include?('decoy_'))
				puts "Error: Input file must not contain target and decoy results. Please complete the target/decoy approach first by running the 'Filter by FPR' script. If you are unsatisfied with the results of the FPR filter, you can alternatively filter by a fixed score threshold."
				exit 1
			end
			
			lk_PeptideInProtein[ls_Peptide] ||= Hash.new
			lk_PeptideInProtein[ls_Peptide][ls_DefLine] ||= Array.new
			lb_AlreadyThere = false
			li_CorrectedStart = li_Start - 1
			lk_PeptideInProtein[ls_Peptide][ls_DefLine].each do |lk_Info|
				lb_AlreadyThere = true if lk_Info['start'] == li_CorrectedStart
			end
			lk_PeptideInProtein[ls_Peptide][ls_DefLine].push({'start' => li_CorrectedStart}) unless lb_AlreadyThere
			
			# correct charge in scan name (because when there are multiple charges,
			# only one version of the spectrum may have been sent to OMSSA, because
			# it obviously doens't have to believe the input file, and in that case
			# the charge in the dta filename must be corrected)
			lk_ScanParts = ls_Scan.split('.')
			# remove trailing .dta if it's there
			lk_ScanParts.slice!(-1, 1) if (lk_ScanParts.last == 'dta')
			begin
				li_TestStartScan = Integer(lk_ScanParts[-3])
				li_TestStopScan = Integer(lk_ScanParts[-2])
				li_TestCharge = Integer(lk_ScanParts[-1])
				if (li_TestCharge < 1 || (li_TestStopScan < li_TestStartScan))
					li_ErrorCount += 1
					ls_ErrorLine = ls_Scan
					next
				end
			rescue StandardError => e
				li_ErrorCount += 1
				next
			end
			lk_ScanParts[-1] = li_Charge.to_s
			ls_Scan = lk_ScanParts.join('.')
			
			# determine spot name from scan name by cutting off start scan,
			# end scan, and charge
			ls_Spot = lk_ScanParts.slice(0, lk_ScanParts.size - 3).join('.')
			
			if (lb_HasFpr)
				lf_ThisTargetFpr = lk_Line[lk_HeaderMap['targetfpr']].to_f
				lf_TargetFpr ||= lf_ThisTargetFpr
				if (lf_TargetFpr != lf_ThisTargetFpr)
					puts "Error: Target FPR is not constant throughout the whole file."
					exit 1
				end
				lf_ThisActualFpr = lk_Line[lk_HeaderMap['actualfpr']].to_f
				lk_ActualFpr[ls_Spot] ||= lf_ThisActualFpr
				if (lf_ThisActualFpr != lk_ActualFpr[ls_Spot])
					puts "Error: Actual FPR is not constant per band throughout the whole file."
					exit 1
				end
				lf_ThisScoreThreshold = BigDecimal.new(lk_Line[lk_HeaderMap['scorethreshold']])
				lk_ScoreThreshold[ls_Spot] ||= lf_ThisScoreThreshold
				if (lf_ThisScoreThreshold != lk_ScoreThreshold[ls_Spot])
					puts "Error: Score threshold is not constant per band throughout the whole file."
					exit 1
				end
				unless lb_OldFormatWithoutScoreThresholdType
					ls_ThisScoreThresholdType = lk_Line[lk_HeaderMap['scorethresholdtype']].strip
					ls_ScoreThresholdType ||= ls_ThisScoreThresholdType
					if (ls_ScoreThresholdType != ls_ThisScoreThresholdType)
						puts "Error: Score threshold type is not constant throughout the whole file."
						exit 1
					end
				end
			elsif (lb_HasFixedScoreThreshold)
				lf_ThisScoreThreshold = BigDecimal.new(lk_Line[lk_HeaderMap['scorethreshold']])
				lk_ScoreThreshold[ls_Spot] ||= lf_ThisScoreThreshold
				if (lf_ThisScoreThreshold != lk_ScoreThreshold[ls_Spot])
					puts "Error: Score threshold is not constant per band throughout the whole file."
					exit 1
				end
				unless lb_OldFormatWithoutScoreThresholdType
					ls_ThisScoreThresholdType = lk_Line[lk_HeaderMap['scorethresholdtype']].strip
					ls_ScoreThresholdType ||= ls_ThisScoreThresholdType
					if (ls_ScoreThresholdType != ls_ThisScoreThresholdType)
						puts "Error: Score threshold type is not constant throughout the whole file."
						exit 1
					end
				end
			end
			
			lk_ScanHash[ls_Scan] ||= Hash.new
			if (!lk_ScanHash[ls_Scan].has_key?(:e) || lf_E < lk_ScanHash[ls_Scan][:e])
				# clear scan hash
				lk_ScanHash[ls_Scan][:peptides] = {ls_Peptide => {:measuredMass => lf_Mass, :calculatedMass => lf_TheoMass, :charge => li_Charge } }
				lk_ScanHash[ls_Scan][:deflines] = [ls_DefLine]
				lk_ScanHash[ls_Scan][:e] = lf_E;
				lk_ScanHash[ls_Scan][:retentionTime] = lf_RetentionTime
				lk_ScanHash[ls_Scan][:mods] = Array.new
				lk_ScanHash[ls_Scan][:mods].push({:peptide => ls_OriginalPeptide, :description => lk_Mods}) unless lk_Mods.empty?
			elsif (lf_E == lk_ScanHash[ls_Scan][:e])
				# update scan hash
				lk_ScanHash[ls_Scan][:peptides][ls_Peptide] = {:measuredMass => lf_Mass, :calculatedMass => lf_TheoMass, :charge => li_Charge }
				lk_ScanHash[ls_Scan][:deflines].push(ls_DefLine)
				lk_ScanHash[ls_Scan][:mods].push({:peptide => ls_OriginalPeptide, :description => lk_Mods}) unless lk_Mods.empty?
			end
		end
	end
	puts "\rReading PSM entries... #{li_EntryCount}." unless ak_Options[:silent]
	if (li_ErrorCount > 0)
		puts "ATTENTION: The scan name was not as expected in #{li_ErrorCount} of #{li_EntryCount} lines, these lines have been ignored."
		puts "The scan name is expected to end with (start scan).(end scan).(charge)."
		puts "The last of these erroneous lines is:"
		puts ls_ErrorLine
	end
	
	# reconstruct score thresholds and actual fpr
	if (lk_ActualFpr.keys.size == 1)
		# we only have one spot, so it's per spot score threshold determation!
		lb_GlobalFpr = false
	else
		if (lk_ActualFpr.values.uniq.size == 1 && lk_ScoreThreshold.values.uniq.size == 1)
			# all actual fpr and score thresholds are the same, so it's global!
			lb_GlobalFpr = true
			lk_ScoreThreshold = {'(global)' => lk_ScoreThreshold.values.first}
			lk_ActualFpr = {'(global)' => lk_ActualFpr.values.first}
		else
			lb_GlobalFpr = false
		end
	end
	
	# clean up scan hash, throw out all scans in which several peptides with
	# the same score were found
	# TODO: maybe we could prefer model peptides here, and keep equal gpf peptides?
	lk_ScanHash.reject! do |x, y|
		y[:peptides].size > 1
	end
	
	lk_PeptideHash = Hash.new
	#WLQYSEVIHAR:
	#  :scans: [MT_HydACPAN_1_300407.100.100.2, ...]
	#  :spots: (MT_HydACPAN_1_300407) (set)
	#  :found: {gpf, models, sixframes}
	#  :proteins: {x => true, y => true}
	#  :foundUnmodified: true
	#  :mods:
	#    WLQYsEVIHAR:
	#      'yada yada':
	#        MT_HydACPAN_1_300407: [MT_HydACPAN_1_300407.100.100.2]
	
	lk_ScanHash.keys.each do |ls_Scan|
		ls_Peptide = lk_ScanHash[ls_Scan][:peptides].keys.first
		if !lk_PeptideHash.has_key?(ls_Peptide)
			lk_PeptideHash[ls_Peptide] = Hash.new 
			lk_PeptideHash[ls_Peptide][:scans] = Array.new
			lk_PeptideHash[ls_Peptide][:spots] = Set.new
			lk_PeptideHash[ls_Peptide][:found] = Hash.new
			lk_PeptideHash[ls_Peptide][:proteins] = Hash.new
			lk_PeptideHash[ls_Peptide][:foundUnmodified] = false
			lk_PeptideHash[ls_Peptide][:mods] = Hash.new
		end
		lk_PeptideHash[ls_Peptide][:foundUnmodified] = true if (!lk_ScanHash[ls_Scan][:mods]) || (lk_ScanHash[ls_Scan][:mods].empty?)
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
			if (ls_DefLine.index(ak_Options[:putativePrefix] + 'gpf_') == 0)
				lk_PeptideHash[ls_Peptide][:found][:gpf] = true 
			elsif (ls_DefLine.index(ak_Options[:putativePrefix] + 'ORF_') == 0)
				lk_PeptideHash[ls_Peptide][:found][:sixframes] = true 
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
	lk_SixFramesPeptides = Set.new
	lk_ModelPeptides = Set.new
	lk_ProteinIdentifyingModelPeptides = Set.new
	
	lk_PeptideHash.keys.each do |ls_Peptide|
		lk_GpfPeptides.add(ls_Peptide) if lk_PeptideHash[ls_Peptide][:found].has_key?(:gpf)
		lk_SixFramesPeptides.add(ls_Peptide) if lk_PeptideHash[ls_Peptide][:found].has_key?(:sixframes)
		lk_ModelPeptides.add(ls_Peptide) if lk_PeptideHash[ls_Peptide][:found].has_key?(:models)
		lk_ProteinIdentifyingModelPeptides.add(ls_Peptide) if lk_PeptideHash[ls_Peptide][:proteins].size == 1
	end
	
	lk_Proteins = Hash.new
	# lk_Proteins:
	#   extgeneshsomething: [WLQYSEVIHAR, LYDEELQAIAK]
	lk_ProteinIdentifyingModelPeptides.each do |ls_Peptide|
		if (lk_PeptideHash[ls_Peptide][:proteins].size != 1)
			puts 'ATTENTION: There was an internal error, probably you just stumbled upon a bug.'
			puts "#{__FILE__}:#{__LINE__}"
			exit 1
		end
		ls_Protein = lk_PeptideHash[ls_Peptide][:proteins].keys.first
		lk_Proteins[ls_Protein] ||= Array.new
		lk_Proteins[ls_Protein].push(ls_Peptide)
		lk_PeptideHash[ls_Peptide][:scans].each do |ls_Scan|
			lk_ScanParts = ls_Scan.split('.')
			# remove trailing .dta if it's there
			lk_ScanParts.slice!(-1, 1) if (lk_ScanParts.last == 'dta')
			# determine spot name
			ls_Spot = lk_ScanParts.slice(0, lk_ScanParts.size - 3).join('.')
			lk_SpectralCounts[:proteins][ls_Protein] ||= Hash.new
			lk_SpectralCounts[:proteins][ls_Protein][:total] ||= 0
			lk_SpectralCounts[:proteins][ls_Protein][:total] += 1
			lk_SpectralCounts[:proteins][ls_Protein][ls_Spot] ||= 0
			lk_SpectralCounts[:proteins][ls_Protein][ls_Spot] += 1
			lk_SpectralCounts[:peptides][ls_Peptide] ||= Hash.new
			lk_SpectralCounts[:peptides][ls_Peptide][:total] ||= 0
			lk_SpectralCounts[:peptides][ls_Peptide][:total] += 1
			lk_SpectralCounts[:peptides][ls_Peptide][ls_Spot] ||= 0
			lk_SpectralCounts[:peptides][ls_Peptide][ls_Spot] += 1
		end
	end
	
	lk_SafeProteins = Set.new(lk_Proteins.keys.select do |ls_Protein|
		li_DistinctPeptideCount = lk_Proteins[ls_Protein].size
		li_GpfPeptideCount = 0
		lk_Proteins[ls_Protein].each do |ls_Peptide|
			li_GpfPeptideCount += 1 if lk_PeptideHash[ls_Peptide][:found].include?(:gpf)
		end
		(li_DistinctPeptideCount >= 2) || (li_GpfPeptideCount >= 1)
	end)

	lk_Result = Hash.new
	
	lk_Result[:scanHash] = lk_ScanHash
	lk_Result[:peptideHash] = lk_PeptideHash
	lk_Result[:gpfPeptides] = lk_GpfPeptides
	lk_Result[:sixFramesPeptides] = lk_SixFramesPeptides
	lk_Result[:modelPeptides] = lk_ModelPeptides
	lk_Result[:proteinIdentifyingModelPeptides] = lk_ProteinIdentifyingModelPeptides
	lk_Result[:proteins] = lk_Proteins
	lk_Result[:scoreThresholds] = lk_ScoreThreshold
	lk_Result[:actualFpr] = lk_ActualFpr
	lk_Result[:targetFpr] = lf_TargetFpr
	lk_Result[:scoreThresholdType] = ls_ScoreThresholdType
	lk_Result[:hasGlobalFpr] = lb_GlobalFpr
	lk_Result[:spectralCounts] = lk_SpectralCounts
	lk_Result[:safeProteins] = lk_SafeProteins
	lk_Result[:peptideInProtein] = lk_PeptideInProtein
	
	return lk_Result
end

