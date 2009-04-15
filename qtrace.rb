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
require 'include/externaltools'
require 'include/fasta'
require 'include/formats'
require 'include/misc'
require 'bigdecimal'
require 'fileutils'
require 'yaml'


class QTrace < ProteomaticScript
	def cutMax(af_Value, ai_Max = 10000, ai_Places = 2)
		return af_Value > ai_Max.to_f ? ">#{ai_Max}" : sprintf("%1.#{ai_Places}f", af_Value)
	end
	
	def niceRatio(af_Value)
		return af_Value if af_Value.class == String
		return '-inf' if af_Value.class == Float && af_Value == 0.0
		return sprintf('%s%1.2f', (af_Value < 1.0) ? '-' : '+', (af_Value < 1.0) ? (1.0 / af_Value) : af_Value)
	end
	
	def meanAndStandardDeviation(ak_Values)
		lb_AllNumbers = true
		lb_AllEqual = true
		lk_FirstValue = ak_Values.first
		ak_Values.each { |x| lb_AllNumbers = false if x.class != Float }
		ak_Values.each { |x| lb_AllEqual = false if x != lk_FirstValue }
		unless lb_AllNumbers
			if (lb_AllEqual)
				return lk_FirstValue, ''
			else
				lk_Mixed = Set.new
				ak_Values.each { |x| lk_Mixed.add("#{niceRatio(x)} (#{ak_Values.count(x)})") if x.class != Float }
				ld_Mean = 0.0
				li_Count = 0
				ak_Values.each do |x|
					if x.class == Float
						ld_Mean += x
						li_Count += 1
					end
				end
				if (li_Count > 0)
					ld_Mean /= li_Count
					lk_Mixed.add(sprintf('%1.2f (%d)', ld_Mean, li_Count))
				end
				return "mixed: #{lk_Mixed.to_a.sort.join(', ')}", ''
			end
		end
		ld_Mean = 0.0
		ld_Sd = 0.0
		ak_Values.each { |x| ld_Mean += x }
		ld_Mean /= ak_Values.size
		ak_Values.each { |x| ld_Sd += ((x - ld_Mean) ** 2.0) }
		ld_Sd /= ak_Values.size
		ld_Sd = Math.sqrt(ld_Sd)
		return ld_Mean, ld_Sd
	end
	
	def run()
		lk_Peptides = Array.new

		lk_PeptideInProtein = Hash.new
		
		# get peptides from PSM list
		unless @input[:psmFile].empty?
			lk_Result = loadPsm(@input[:psmFile].first) 
			
			lk_ScanHash = lk_Result[:scanHash]
			lk_PeptideHash = lk_Result[:peptideHash]
			lk_Proteins = lk_Result[:proteins]
			lk_ScoreThresholds = lk_Result[:scoreThresholds]
			lk_ActualFpr = lk_Result[:actualFpr]
			lk_PeptideInProtein = lk_Result[:peptideInProtein]
			
			lk_ScanHash.each do |ls_Scan, lk_Scan|
				unless (lk_Scan[:retentionTime])
					puts 'Error: The PSM list you specified does not contain any retention time information.'
					puts 'SimQuant cannot continue without that information. Please re-run the OMSSA search to get a PSM list which includes retention times.'
					exit 1
				end
			end
			
			lk_Peptides += lk_PeptideHash.keys
		else
			if (@param[:useMaxIdentificationQuantitationTimeDifference])
				puts 'You need to specify at least one PSM list file if you require a MS2 event close to every quantitation event.'
				exit
			end
		end
		
		# get peptides from parameters
		lk_Peptides += @param[:peptides].split(%r{[,;\s/]+})
		
		# get peptides from peptides files
		@input[:peptideFiles].each do |ls_Path|
			lk_Peptides += File::read(ls_Path).split("\n")
		end
		
		lk_Peptides.uniq!
		lk_Peptides.collect! { |x| x.upcase }
		
		# convert SEQUEST-type peptides X.PEPTIDEK.X to PEPTIDEK
		lk_Peptides.collect! do |ls_Peptide|
			if ls_Peptide.include?('.')
				lk_Peptide = ls_Peptide.split('.')
				if (lk_Peptide.size == 3)
					ls_Peptide = lk_Peptide[1] 
				else
					puts "Error: A bad peptide was encountered: #{ls_Peptide}."
					exit 1
				end
			end
			ls_Peptide
		end

		lk_Peptides.reject! do |ls_Peptide|
			# reject peptide if it's empty or if it does not contain arginine (R)
			ls_Peptide.strip.empty? || (!ls_Peptide.include?('R'))
		end

		# handle amino acid exclusion list
		ls_ExcludeListTemplate = 'ARNDCEQGHILKMFPSTWYV'
		ls_ExcludeList = ''
		(0...ls_ExcludeListTemplate.size).each do |i|
			 ls_ExcludeList += ls_ExcludeListTemplate[i, 1] if (@param[:excludeAminoAcids].upcase.include?(ls_ExcludeListTemplate[i, 1]))
		end
		# ls_ExcludeList now contains all amino acids that should be chucked out
		(0...ls_ExcludeList.size).each do |i|
			lk_Peptides.reject! { |ls_Peptide| ls_Peptide.include?(ls_ExcludeList[i, 1]) }
		end
		
		if lk_Peptides.empty? && @input[:peptideFiles].empty?
			puts 'Error: no peptides have been specified.'
			puts 'Maybe there were peptides, but all were excluded due to the fact that each of them contained amino acids that you want to exclude.'
			exit 1
		end
		
		ls_TempPath = tempFilename('simquant')
# 		ls_TempPath = '/flipbook/spectra/quantitation/temp-simquant20090415-32662-uwranb-0'
		ls_CsvPath = File::join(ls_TempPath, 'out.csv')
		ls_XhtmlPath = File::join(ls_TempPath, 'out.xhtml')
		ls_PeptidesPath = File::join(ls_TempPath, 'peptides.txt')
		ls_PeptideMatchYamlPath = File::join(ls_TempPath, 'matchpeptides.yaml')
		FileUtils::mkpath(ls_TempPath)

		# write all target peptides into one file
		File::open(ls_PeptidesPath, 'w') do |lk_Out|
			lk_Out.puts lk_Peptides.join("\n")
		end

		# update lk_PeptideInProtein
		unless @input[:modelFiles].empty?
			print 'Matching peptides to proteins...'
			ls_Command = "\"#{ExternalTools::binaryPath('simquant.matchpeptides')}\" --output \"#{ls_PeptideMatchYamlPath}\" --peptides #{lk_Peptides.join(' ')} --peptideFiles #{@input[:peptideFiles].collect {|x| '"' + x + '"'}.join(' ')} --modelFiles #{@input[:modelFiles].collect {|x| '"' + x + '"'}.join(' ')}"
			runCommand(ls_Command, true)
			lk_PeptideMatches = YAML::load_file(ls_PeptideMatchYamlPath)
			puts 'done.'
			lk_PeptideMatches.keys.each do |ls_Peptide|
				lk_PeptideInProtein[ls_Peptide] ||= Hash.new
				lk_PeptideMatches[ls_Peptide].keys.each do |ls_Protein|
					lk_PeptideInProtein[ls_Peptide][ls_Protein] ||= Array.new
					lk_PeptideMatches[ls_Peptide][ls_Protein].each do |lk_NewHit|
						# this is each hit from the external matchpeptides result file,
						# now check against each entry in the already existing 
						# lk_PeptideInProtein hash whether there's something there
						# already
						li_AlreadyThereIndex = nil
						(0...lk_PeptideInProtein[ls_Peptide][ls_Protein].size).each do |i|
							lk_HereHit = lk_PeptideInProtein[ls_Peptide][ls_Protein][i]
							if lk_HereHit['start'] == lk_NewHit['start']
								li_AlreadyThereIndex = i
								break
							end
						end
						if (li_AlreadyThereIndex)
							# There's already something. See if we can update that.
							# In fact, we just chuck out the old entry and add the new one,
							# because we additionally get stop and proteinlength info now.
							# The old info coming from OMSSA should have the start only.
							lk_PeptideInProtein[ls_Peptide][ls_Protein].slice!(li_AlreadyThereIndex, 1)
							lk_PeptideInProtein[ls_Peptide][ls_Protein].push(lk_NewHit)
						else
							# It's not there yet, insert it.
							lk_PeptideInProtein[ls_Peptide][ls_Protein].push(lk_NewHit)
						end
					end
				end
			end
		end
		
		ls_Command = "\"#{ExternalTools::binaryPath('simquant.simquant')}\" --scanType #{@param[:scanType]} --isotopeCount #{@param[:isotopeCount]} --minCharge #{@param[:minCharge]} --maxCharge #{@param[:maxCharge]} --minSnr #{@param[:minSnr]} --massAccuracy #{@param[:includeMassAccuracy]} --excludeMassAccuracy #{@param[:excludeMassAccuracy]} --csvOutput yes --csvOutputTarget \"#{ls_CsvPath}\" --xhtmlOutput yes --xhtmlOutputTarget \"#{ls_XhtmlPath}\" --spectraFiles #{@input[:spectraFiles].collect {|x| '"' + x + '"'}.join(' ')} --peptideFiles \"#{ls_PeptidesPath}\" --printStatistics #{@param[:printStatistics]}"
		runCommand(ls_Command, true)
		
		lk_HeaderMap, lk_Results = loadCsvResults(ls_CsvPath)
		
		li_ChuckedOutBecauseOfTimeDifference = 0
		li_ChuckedOutBecauseOfNoMs2Identification = 0
		lk_UnidentifiedPeptides = Set.new
		lk_TooHighTimeDifferencePeptides = Set.new

		# chuck out quantitation events that have no corresponding MS2 identification event
		if @param[:useMaxIdentificationQuantitationTimeDifference]
			lk_Results.reject! do |lk_Hit|
				lb_RejectThis = true
				lb_RejectedDueToTimeDifference = false
				ls_Peptide = lk_Hit[lk_HeaderMap['peptide']]
				ls_Spot = lk_Hit[lk_HeaderMap['filename']]
				if lk_PeptideHash && lk_PeptideHash.include?(ls_Peptide)
					lk_PeptideHash[ls_Peptide][:scans].each do |ls_Scan|
						ls_Ms2Spot = ls_Scan.split('.').first
						lb_RejectThis = false if ((lk_ScanHash[ls_Scan][:retentionTime] - lk_Hit[lk_HeaderMap['retentiontime']].to_f).abs <= @param[:maxIdentificationQuantitationTimeDifference]) && (ls_Spot == ls_Ms2Spot)
						lb_RejectedDueToTimeDifference = true if lb_RejectThis
						lk_TooHighTimeDifferencePeptides.add(ls_Peptide)
					end
				else
					li_ChuckedOutBecauseOfNoMs2Identification += 1
					lk_UnidentifiedPeptides.add(ls_Peptide)
				end
				li_ChuckedOutBecauseOfTimeDifference += 1 if lb_RejectedDueToTimeDifference
				lb_RejectThis
			end
		end
		
		if (li_ChuckedOutBecauseOfNoMs2Identification > 0) || (li_ChuckedOutBecauseOfTimeDifference > 0)
			puts 'Attention: Some quantitation events have been removed.'
			puts "...because there was no MS2 identification: #{li_ChuckedOutBecauseOfNoMs2Identification}" if li_ChuckedOutBecauseOfNoMs2Identification > 0
			puts "...because the SimQuant/MS2 RT difference was too high: #{li_ChuckedOutBecauseOfTimeDifference}" if li_ChuckedOutBecauseOfTimeDifference > 0
		else
			puts "No quantitation events have been removed." if @param[:useMaxIdentificationQuantitationTimeDifference]
		end
		
		lk_QuantifiedPeptides = Set.new
		lk_Results.each { |lk_Hit| lk_QuantifiedPeptides << lk_Hit[lk_HeaderMap['peptide']] }
		lk_MatchedPeptides = lk_QuantifiedPeptides.select do |ls_Peptide|
			lk_PeptideInProtein.include?(ls_Peptide) && lk_PeptideInProtein[ls_Peptide].size == 1
		end
		lk_AmbiguouslyMatchingPeptides = (Set.new(lk_QuantifiedPeptides) - Set.new(lk_MatchedPeptides)).to_a
		
		lk_PeptidesForProtein = Hash.new
		lk_MatchedPeptides.each do |ls_Peptide|
			ls_Protein = lk_PeptideInProtein[ls_Peptide].keys.first
			lk_PeptidesForProtein[ls_Protein] ||= Array.new
			lk_PeptidesForProtein[ls_Protein].push(ls_Peptide) unless lk_PeptidesForProtein[ls_Protein].include?(ls_Peptide)
		end
		lk_PeptidesForProtein.keys.each do |ls_Protein|
			lk_PeptidesForProtein[ls_Protein].sort! do |a, b|
				lk_PeptideInProtein[a][ls_Protein].first['start'] <=> lk_PeptideInProtein[b][ls_Protein].first['start']
			end
		end
		
		# determine protein for each peptide
		lk_PeptideProteinDescription = Hash.new
		lk_QuantifiedPeptides.each do |ls_Peptide|
			ls_Protein = '(not matching to any protein)'
			if (lk_PeptideInProtein[ls_Peptide])
				if (lk_PeptideInProtein[ls_Peptide].size == 1)
					ls_Protein = lk_PeptideInProtein[ls_Peptide].keys.first
				else
					ls_Protein = "(matching to #{lk_PeptideInProtein[ls_Peptide].size} proteins)"
				end
			end
			lk_PeptideProteinDescription[ls_Peptide] = ls_Protein
		end
		
		
		# inject ratio, proline count, protein
		lk_HeaderMapArray = Array.new
		lk_HeaderMapReversed = lk_HeaderMap.invert
		lk_HeaderMapReversed.keys.sort.each { |li_Index| lk_HeaderMapArray << lk_HeaderMapReversed[li_Index] }
		
		li_ProteinIndex = lk_HeaderMapArray.index('peptide')
		lk_HeaderMapArray.insert(li_ProteinIndex, 'protein')
		
		li_RatioIndex = lk_HeaderMapArray.index('amountheavy') + 1
		lk_HeaderMapArray.insert(li_RatioIndex, 'ratio')
		
		li_ProlineCountIndex = lk_HeaderMapArray.size
		lk_HeaderMapArray.insert(li_ProlineCountIndex, 'prolinecount')
		
		lk_Results.collect! do |lk_Hit|
			lk_NewHit = lk_Hit.dup
			lk_NewHit.insert(li_ProteinIndex, lk_PeptideProteinDescription[lk_Hit[lk_HeaderMap['peptide']]])
			lk_NewHit.insert(li_RatioIndex, (lk_Hit[lk_HeaderMap['amountlight']].to_f / lk_Hit[lk_HeaderMap['amountheavy']].to_f).to_s)
			lk_NewHit.insert(li_ProlineCountIndex, lk_Hit[lk_HeaderMap['peptide']].downcase.count('p'))
			lk_NewHit
		end
		
		# update header map
		lk_HeaderMap = Hash.new
		lk_HeaderMapArray.each_with_index do |ls_Key, li_Index|
			lk_HeaderMap[ls_Key] = li_Index
		end
		
		# promote results to spot => peptide => event ids
		lk_ResultsBySpotAndPeptide = Hash.new
		lk_Results.each_with_index do |lk_Hit, li_Index|
			ls_Filename = lk_Hit[lk_HeaderMap['filename']]
			ls_Peptide = lk_Hit[lk_HeaderMap['peptide']]
			lk_ResultsBySpotAndPeptide[ls_Filename] ||= Hash.new
			lk_ResultsBySpotAndPeptide[ls_Filename][ls_Peptide] ||= Array.new
			lk_ResultsBySpotAndPeptide[ls_Filename][ls_Peptide].push(li_Index)
		end
		
		if (lk_Results.size == 0)
			puts 'No peptides could be quantified.'
		end
		
		if @output[:proteinCsv]
			File.open(@output[:proteinCsv], 'w') do |lk_Out|
				lk_Out.puts lk_HeaderMapArray.to_csv
				lk_Results.each do |lk_Hit|
					lk_Out.puts lk_Hit.to_csv
				end
			end
		end
		
		if @output[:xhtmlReport]
			FileUtils::cp(ls_XhtmlPath, @output[:xhtmlReport])
		end
		
# 		lk_AllProteins = Hash.new
# 		lk_Results.each do |lk_Hit|
# 			ls_Protein = lk_Hit[lk_HeaderMap['protein']]
# 			lk_AllProteins[ls_Protein] ||= Array.new
# 			lk_AllProteins[ls_Protein] << lk_Hit
# 		end
# 		
# 		lk_AllProteins.each_pair do |ls_Protein, lk_Hits|
# 			lk_Row = Array.new
# 			lk_Row << ls_Protein
# 			lk_Row << lk_Hits.size
# 			lk_Ratios = Array.new
# 			lk_RatioTypes = Set.new
# 			lk_Hits.each do |x| 
# 				lk_Ratios << x[lk_HeaderMap['ratio']]
# 				lf_Light = x[lk_HeaderMap['amountlight']].to_f
# 				lf_Heavy = x[lk_HeaderMap['amountheavy']].to_f
# 				lk_RatioTypes << 'light only' if lf_Light > 0.0 && lf_Heavy == 0.0
# 				lk_RatioTypes << 'heavy only' if lf_Light == 0.0 && lf_Heavy > 0.0
# 				lk_RatioTypes << 'pair' if lf_Light > 0.0 && lf_Heavy > 0.0
# 			end
# 			lk_Row << lk_RatioTypes.size
# 			lk_Row << lk_RatioTypes.to_a.sort.join('/')
# 			puts lk_Row.to_csv()
# 		end
		
		
=begin		
		if @output[:xhtmlReport]
			File.open(@output[:xhtmlReport], 'w') do |lk_Out|
				lk_Out.puts "<?xml version='1.0' encoding='utf-8' ?>"
				lk_Out.puts "<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.1//EN' 'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd'>"
				lk_Out.puts "<html xmlns='http://www.w3.org/1999/xhtml' xml:lang='de'>"
				lk_Out.puts '<head>'
				lk_Out.puts '<title>SimQuant Report</title>'
				printStyleSheet(lk_Out)
				lk_Out.puts '</head>'
				lk_Out.puts '<body>'
				lk_Out.puts "<h1>SimQuant Report</h1>"
				lk_Out.puts '<p>'
				lk_Out.puts "Trying charge states #{@param[:minCharge]} to #{@param[:maxCharge]}.<br />"
				lk_Out.puts "Quantitation has been attempted in #{@param[:scanType] == 'sim' ? 'SIM scans only' : (@param[:scanType] == 'ms1' ? 'full scans only' : 'all MS1 scans')}, considering #{@param[:isotopeCount]} isotope peaks for both the unlabeled and the labeled ions.<br />"
				lk_Out.puts '</p>'
				
				lk_QuantifiedPeptides = Array.new
				lk_Results.each do |ls_Spot, lk_SpotResults| 
					next unless lk_SpotResults
					lk_QuantifiedPeptides += lk_SpotResults.keys
				end
				lk_UnmatchedPeptides = lk_QuantifiedPeptides.select do |ls_Peptide|
					(!lk_PeptideInProtein[ls_Peptide]) || lk_PeptideInProtein[ls_Peptide].empty?
				end
				lk_OvermatchedPeptides = lk_QuantifiedPeptides.select do |ls_Peptide|
					lk_PeptideInProtein[ls_Peptide] && lk_PeptideInProtein[ls_Peptide].size > 1
				end
				lk_MatchedPeptides = lk_QuantifiedPeptides.select do |ls_Peptide|
					lk_PeptideInProtein[ls_Peptide] && lk_PeptideInProtein[ls_Peptide].size == 1
				end
				
				lk_Out.puts '<h2>Contents</h2>'
				lk_Out.puts '<ol>'
				lk_Out.puts "<li><a href='#header-quantified-proteins'>Quantified proteins</a></li>" unless lk_MatchedPeptides.empty?
				lk_Out.puts "<li><a href='#header-unmatched-peptides'>Unmatched peptides</a></li>" unless lk_UnidentifiedPeptides.empty?
				lk_Out.puts "<li><a href='#header-overmatched-peptides'>Ambiguous peptides</a></li>" unless lk_OvermatchedPeptides.empty?
				lk_Out.puts "<li><a href='#header-quantified-peptides'>Quantified peptides</a></li>"
				lk_Out.puts "</ol>"

				lk_PeptidesForProtein = Hash.new
				lk_MatchedPeptides.each do |ls_Peptide|
					ls_Protein = lk_PeptideInProtein[ls_Peptide].keys.first
					lk_PeptidesForProtein[ls_Protein] ||= Array.new
					lk_PeptidesForProtein[ls_Protein].push(ls_Peptide) unless lk_PeptidesForProtein[ls_Protein].include?(ls_Peptide)
				end
				lk_PeptidesForProtein.keys.each do |ls_Protein|
					lk_PeptidesForProtein[ls_Protein].sort! do |a, b|
						lk_PeptideInProtein[a][ls_Protein].first['start'] <=> lk_PeptideInProtein[b][ls_Protein].first['start']
					end
				end

				# determine merged results for each spot/peptide
				lk_PeptideMergedResults = Hash.new
				lk_Results.keys.each do |ls_Spot|
					lk_PeptideMergedResults[ls_Spot] = Hash.new
					next unless lk_Results[ls_Spot]
					lk_Results[ls_Spot].keys.each do |ls_Peptide|
						lk_PeptideMergedResults[ls_Spot][ls_Peptide] = Hash.new
						# determine merged ratio/snr
						lk_MergedSnr = Array.new
						lk_MergedRatio = Array.new
						lf_MergedUnlabeledAmount = 0.0
						lf_MergedLabeledAmount = 0.0
						
						lk_Results[ls_Spot][ls_Peptide].each do |lk_Scan|
							lk_MergedSnr.push(lk_Scan['snr'])
							lk_MergedRatio.push(lk_Scan['ratio'])
							lf_MergedUnlabeledAmount += lk_Scan['amountUnlabeled']
							lf_MergedLabeledAmount += lk_Scan['amountLabeled']
						end
						ld_MergedSnrMean, ld_MergedSnrSd = meanAndStandardDeviation(lk_MergedSnr)
						ld_MergedRatioMean, ld_MergedRatioSd = meanAndStandardDeviation(lk_MergedRatio)
						lk_PeptideMergedResults[ls_Spot][ls_Peptide][:snrMean] = ld_MergedSnrMean
						lk_PeptideMergedResults[ls_Spot][ls_Peptide][:snrSd] = ld_MergedSnrSd
						lk_PeptideMergedResults[ls_Spot][ls_Peptide][:ratioMean] = ld_MergedRatioMean
						lk_PeptideMergedResults[ls_Spot][ls_Peptide][:ratioSd] = ld_MergedRatioSd
						lk_PeptideMergedResults[ls_Spot][ls_Peptide][:count] = lk_MergedSnr.size
						lk_PeptideMergedResults[ls_Spot][ls_Peptide][:ratioMeanPrint] = niceRatio(ld_MergedRatioMean)
						lk_PeptideMergedResults[ls_Spot][ls_Peptide][:ratioSdPrint] = lk_MergedSnr.size == 1 || ld_MergedRatioSd.class == String ? '&ndash;' : sprintf('%1.2f', ld_MergedRatioSd)
					end
				end
				
				# determine merged results for each spot/protein
				lk_ProteinMergedResults = Hash.new
				lk_Results.keys.each do |ls_Spot|
					lk_ProteinMergedResults[ls_Spot] = Hash.new
					lk_Proteins = lk_MatchedPeptides.select { |x| lk_Results[ls_Spot].keys.include?(x) }.collect do |ls_Peptide|
						lk_PeptideInProtein[ls_Peptide].keys.first
					end
					lk_Proteins.sort! { |a, b| String::natcmp(a, b) }
					lk_Proteins.uniq!
					
					lk_Proteins.each do |ls_Protein|
						lk_ProteinMergedResults[ls_Spot][ls_Protein] = Hash.new
						# determine merged ratio/snr
						lk_MergedSnr = Array.new
						lk_MergedRatio = Array.new
						lf_MergedUnlabeledAmount = 0.0
						lf_MergedLabeledAmount = 0.0
						lk_PeptidesForProtein[ls_Protein].each do |ls_Peptide|
							next unless lk_Results[ls_Spot].keys.include?(ls_Peptide)
							lk_Results[ls_Spot][ls_Peptide].each do |lk_Scan|
								lk_MergedSnr.push(lk_Scan['snr'])
								lk_MergedRatio.push(lk_Scan['ratio'])
								lf_MergedUnlabeledAmount += lk_Scan['amountUnlabeled']
								lf_MergedLabeledAmount += lk_Scan['amountLabeled']
							end
						end
						ld_MergedSnrMean, ld_MergedSnrSd = meanAndStandardDeviation(lk_MergedSnr)
						ld_MergedRatioMean, ld_MergedRatioSd = meanAndStandardDeviation(lk_MergedRatio)
						lk_ProteinMergedResults[ls_Spot][ls_Protein][:snrMean] = ld_MergedSnrMean
						lk_ProteinMergedResults[ls_Spot][ls_Protein][:snrSd] = ld_MergedSnrSd
						lk_ProteinMergedResults[ls_Spot][ls_Protein][:ratioMean] = ld_MergedRatioMean
						lk_ProteinMergedResults[ls_Spot][ls_Protein][:ratioSd] = ld_MergedRatioSd
						lk_ProteinMergedResults[ls_Spot][ls_Protein][:count] = lk_MergedSnr.size
						lk_ProteinMergedResults[ls_Spot][ls_Protein][:ratioMeanPrint] = niceRatio(ld_MergedRatioMean)
						lk_ProteinMergedResults[ls_Spot][ls_Protein][:ratioSdPrint] = lk_MergedSnr.size == 1 || ld_MergedRatioSd.class == String ? '&ndash;' : sprintf('%1.2f', ld_MergedRatioSd)
					end
				end
				
				unless lk_MatchedPeptides.empty?
					lk_Out.puts "<h2 id='header-quantified-proteins'>Quantified proteins</h2>"
					
					lk_Out.puts "<table>"
					lk_Out.puts "<tr><th rowspan='2'>Band / Protein / Peptides</th><th rowspan='2'>Elution profile</th><th rowspan='2'>Peptide location in protein</th><th rowspan='2'>Count</th><th colspan='2'>Ratio</th></tr>"
					lk_Out.puts "<tr><th>mean</th><th>sd</th></tr>"
					
					lk_Results.keys.sort { |a, b| String::natcmp(a, b) }.each do |ls_Spot|
						lk_Out.puts "<tr><td style='border: none' colspan='6'></td></tr>"
						lk_Out.puts "<tr style='background-color: #ddd;'>"
						lk_Out.puts "<td colspan='6'><b>#{ls_Spot}</b></td>"
						lk_Out.puts "</tr>"
						
						lk_Proteins = lk_MatchedPeptides.select { |x| lk_Results[ls_Spot].keys.include?(x) }.collect do |ls_Peptide|
							lk_PeptideInProtein[ls_Peptide].keys.first
						end
						lk_Proteins.sort! { |a, b| String::natcmp(a, b) }
						lk_Proteins.uniq!
						
						lk_Proteins.each do |ls_Protein|
							lk_Out.puts "<tr><td style='border: none' colspan='6'></td></tr>"
							lk_Out.puts "<tr style='background-color: #eee;'>"
							lk_Out.puts "<td colspan='3'>#{ls_Protein}</td>"
							lk_Out.puts "<td style='text-align: right;'>#{lk_ProteinMergedResults[ls_Spot][ls_Protein][:count]}</td>"
							lk_Out.puts "<td style='text-align: right;'>#{lk_ProteinMergedResults[ls_Spot][ls_Protein][:ratioMeanPrint]}</td>"
							lk_Out.puts "<td style='text-align: right;'>#{lk_ProteinMergedResults[ls_Spot][ls_Protein][:ratioSdPrint]}</td>"
							lk_Out.puts "</tr>"
							
							lk_PeptidesForProtein[ls_Protein].each do |ls_Peptide|
								next unless lk_Results[ls_Spot].keys.include?(ls_Peptide)
								lk_Out.puts "<tr>"
								li_Width = 256
								ls_PeptideInProteinSvg = ''
								
								lk_Out.puts "<td><a href='##{ls_Spot}-#{ls_Peptide}'>#{ls_Peptide}</a></td>"
								lk_Out.puts '<td>'
								if (@param[:showElutionProfile])
									ls_Svg = "<svg style='margin-left: 4px;' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' xmlns:ev='http://www.w3.org/2001/xml-events' version='1.1' baseProfile='full' width='#{li_Width}px' height='16px'><rect x='0' y='0' width='#{li_Width}' height='16px' fill='#ddd' />"
									lk_Results[ls_Spot][ls_Peptide].each do |lk_Hit|
										ls_Svg += "<line x1='#{lk_Hit['retentionTime'] / 60.0 * li_Width}' y1='8' x2='#{lk_Hit['retentionTime'] / 60.0 * li_Width}' y2='16' fill='none' stroke='#0080ff' stroke-width='1' />"
									end
									if (lk_PeptideHash)
										lk_PeptideHash[ls_Peptide][:scans].each do |ls_Scan|
											ld_RetentionTime = lk_ScanHash[ls_Scan][:retentionTime]
											ls_Svg += "<line x1='#{ld_RetentionTime / 60.0 * li_Width}' y1='0' x2='#{ld_RetentionTime / 60.0 * li_Width}' y2='8' fill='none' stroke='#000' stroke-width='1' />"
										end
									end
									ls_Svg += "</svg>"
									lk_Out.puts "<div style='float: right'>#{ls_Svg}</div> "
								end
								lk_Out.puts '</td><td>'
								if (@param[:showPeptideInProtein])
									lb_PaintedBackground = false
									ls_Svg = ''
									lk_PeptideInProtein[ls_Peptide][lk_PeptideInProtein[ls_Peptide].keys.first].each do |lk_Line|
										if (lk_Line['length'] && lk_Line['proteinLength'])
											unless lb_PaintedBackground
												ls_Svg += "<svg style='margin-left: 4px;' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' xmlns:ev='http://www.w3.org/2001/xml-events' version='1.1' baseProfile='full' width='#{li_Width}px' height='3px'><line x1='0' y1='1.5' x2='#{li_Width}' y2='1.5' fill='none' stroke='#aaa' stroke-width='1.5' />"
												lb_PaintedBackground = true
											end
											lf_BarWidth = lk_Line['length'].to_f / lk_Line['proteinLength'] * li_Width
											lf_BarWidth = 2.0 if lf_BarWidth < 2.0
											ls_Svg += "<line x1='#{lk_Line['start'].to_f / lk_Line['proteinLength'] * li_Width}' y1='1.5' x2='#{lk_Line['start'].to_f / lk_Line['proteinLength'] * li_Width + lf_BarWidth}' y2='1.5' fill='none' stroke='#000' stroke-width='2' />"
										end
									end
									ls_Svg += "</svg>" if lb_PaintedBackground
									lk_Out.puts "#{ls_Svg}"
								end
								lk_Out.puts '</td>'
								lk_Out.puts "<td style='text-align: right;'>#{lk_PeptideMergedResults[ls_Spot][ls_Peptide][:count]}</td>"
								lk_Out.puts "<td style='text-align: right;'>#{lk_PeptideMergedResults[ls_Spot][ls_Peptide][:ratioMeanPrint]}</td>"
								lk_Out.puts "<td style='text-align: right;'>#{lk_PeptideMergedResults[ls_Spot][ls_Peptide][:ratioSdPrint]}</td>"
								lk_Out.puts "</tr>"
							end
						end
						
					end
					lk_Out.puts "</table>"
				end
				
				# TODO: continue here with unmatched/overmatched peptides
				unless lk_UnmatchedPeptides.empty?
					lk_Out.puts "<h2 id='header-unmatched-peptides'>Unmatched peptides</h2>"
					lk_Out.puts "<p>The following peptides have been quantified, but could not be matched to a protein (maybe because they have been found via <i>de novo</i> prediction and GPF). In order to see which proteins the peptides belong to, you can either supply gene models to SimQuant, or you can use PSM lists (MS2 search results) in the first place instead of peptide lists.</p>"
					ls_Peptides = lk_UnmatchedPeptides.sort.join(', ')
					lk_Out.puts "<p>#{ls_Peptides}</p>"
				end
				
				unless lk_OvermatchedPeptides.empty?
					lk_Out.puts "<h2 id='header-overmatched-peptides'>Ambiguous peptides</h2>"
					lk_Out.puts "<p>The following peptides have been quantified, but match to several proteins.</p>"
					lk_Out.puts "<table><tr><th>Peptide</th><th>Proteins</th></tr>"
					lk_OvermatchedPeptides.sort.each do |ls_Peptide|
						lk_Proteins = lk_PeptideInProtein[ls_Peptide].keys.sort { |a, b| String::natcmp(a, b) }
						lk_Out.puts "<tr><td>#{ls_Peptide}</td><td><ul style='margin:0;'>#{lk_Proteins.collect { |x| '<li>' + x + '</li>'}.join(' ')}</ul></td></tr>"
					end
					lk_Out.puts "</table>"
				end

				lk_Out.puts "<h2 id='header-quantified-peptides'>Quantified peptides</h2>"
				
				lk_Out.puts "<table style='min-width: 820px;'>"
				lk_Out.puts "<tr><th rowspan='2'>Band / Peptide / Scan</th><th rowspan='2'>count</th><th colspan='2'>Ratio</th><th rowspan='2'>SNR</th></tr>"
				lk_Out.puts "<tr><th>mean</th><th>sd</th></tr>"
				lk_Results.keys.sort { |a, b| String::natcmp(a, b) }.each do |ls_Spot|
					lk_Out.puts "<tr><td style='border: none' colspan='5'></td></tr>"
					lk_Out.puts "<tr style='background-color: #ddd;'>"
					lk_Out.puts "<td colspan='5'><b>#{ls_Spot}</b></td>"
					lk_Out.puts "</tr>"
					
					next unless lk_Results[ls_Spot]
					lk_Results[ls_Spot].keys.sort { |a, b| String::natcmp(a, b) }.each do |ls_Peptide|
						lk_Out.puts "<tr><td style='border: none' colspan='5'></td></tr>"
						lk_Out.puts "<tr style='background-color: #eee;' id='#{ls_Spot}-#{ls_Peptide}'><td id='peptide-#{ls_Peptide}'><b>#{ls_Peptide}</b></td>"
						lk_Out.puts "<td style='text-align: right;'>#{lk_PeptideMergedResults[ls_Spot][ls_Peptide][:count]}</td>"
						lk_Out.puts "<td style='text-align: right;'>#{lk_PeptideMergedResults[ls_Spot][ls_Peptide][:ratioMeanPrint]}</td>"
						lk_Out.puts "<td style='text-align: right;'>#{lk_PeptideMergedResults[ls_Spot][ls_Peptide][:ratioSdPrint]}</td>"
						lk_Out.puts "<td style='text-align: right;'>&ndash;</td>"
						lk_Out.puts "</tr>"
						
						lk_Scans = lk_Results[ls_Spot][ls_Peptide]
						lk_Scans.sort! { |a, b| a['retentionTime'] <=> b['retentionTime'] }
						lk_Scans.each do |lk_Scan|
							lk_Out.puts "<tr><td style='border: none' colspan='5'></td></tr>" if @param[:includeSpectra]
							lk_Out.puts "<tr><td>#{ls_Peptide}, scan ##{lk_Scan['id']} (charge #{lk_Scan['charge']}+)</td>"
							lk_Out.puts "<td style='text-align: right;'>&ndash;</td>"
							lk_Out.puts "<td style='text-align: right;'>#{niceRatio(lk_Scan['ratio'])}</td>"
							lk_Out.puts "<td style='text-align: right;'>&ndash;</td>"
							lk_Out.puts "<td style='text-align: right;'>#{cutMax(lk_Scan['snr'])}</td>"
							#lk_Out.puts "<td style='background-color: #b1d28f;' class='clickableCell'>(included)</td>"
							
							lk_Out.puts "</tr>"
							
							if @param[:includeSpectra]
								ls_Svg = File::read(File::join(ls_SvgPath, lk_Scan['svg'] + '.svg'))
								ls_Svg.sub!(/<\?xml.+\?>/, '')
								ls_Svg.sub!(/<svg width=\".+\" height=\".+\"/, "<svg ")
								lk_Out.puts "<tr><td colspan='5'>"
								lk_Out.puts "<div>#{ls_Spot} ##{lk_Scan['id']} @ #{sprintf("%1.2f", lk_Scan['retentionTime'].to_f)} minutes: charge: #{lk_Scan['charge']}+ / #{lk_Scan['filterLine']}</div>"
								lk_Out.puts ls_Svg if @param[:includeSpectra]
								lk_Out.puts "</td></tr>"
							end
						end
					end
				end
				lk_Out.puts "</table>"
				
				lk_Out.puts '</body>'
				lk_Out.puts '</html>'
			end
		end
=end
	end
end

lk_Object = QTrace.new

