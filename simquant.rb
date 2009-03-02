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

class SimQuant < ProteomaticScript
	def cutMax(af_Value, ai_Max = 10000, ai_Places = 2)
		return af_Value > ai_Max.to_f ? ">#{ai_Max}" : sprintf("%1.#{ai_Places}f", af_Value)
	end
	
	def niceRatio(af_Value)
		return sprintf('%s%1.2f', (af_Value < 1.0) ? '-' : '+', (af_Value < 1.0) ? (1.0 / af_Value) : af_Value)
	end
	
	def meanAndStandardDeviation(ak_Values)
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
		#ls_TempPath = "/home/michael/mnt/x/AK Hippler/Ingrid/CAS9/1. Batch/WTWCAN_Mix_130109/Quant full scan/1 % FPR, 10 ppm, no MS2/temp-simquant.3720.0"
		ls_YamlPath = File::join(ls_TempPath, 'out.yaml')
		ls_PeptidesPath = File::join(ls_TempPath, 'peptides.txt')
		ls_PeptideMatchYamlPath = File::join(ls_TempPath, 'matchpeptides.yaml')
		ls_SvgPath = File::join(ls_TempPath, 'svg')
		FileUtils::mkpath(ls_TempPath)
		FileUtils::mkpath(ls_SvgPath)

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
		
		ls_Command = "\"#{ExternalTools::binaryPath('simquant.simquant')}\" --scanType #{@param[:scanType]} --isotopeCount #{@param[:isotopeCount]} --minSnr #{@param[:minSnr]} --massAccuracy #{@param[:massAccuracy]} --textOutput no --yamlOutput yes --yamlOutputTarget \"#{ls_YamlPath}\" --svgOutPath \"#{ls_SvgPath}\" --spectraFiles #{@input[:spectraFiles].collect {|x| '"' + x + '"'}.join(' ')} --peptideFiles \"#{ls_PeptidesPath}\" --printStatistics #{@param[:printStatistics]}"
		runCommand(ls_Command, true)
		
		lk_Results = YAML::load_file(ls_YamlPath)
		li_QuantiationEventCount = 0
		
		# replace all floats with BigDecimals
		if (lk_Results['results'])
			lk_Results['results'].each do |ls_Band, lk_Band|
				lk_Band.each do |ls_Peptide, lk_Matches|
				li_QuantiationEventCount += lk_Matches.size
					(0...lk_Matches.size).each do |li_MatchIndex|
						lk_Value = lk_Matches[li_MatchIndex]['snr']
						if (lk_Value.class == String)
							lk_Value = BigDecimal.new(lk_Value)
						elsif (lk_Value.class == Float)
							lk_Value = BigDecimal.new(lk_Value.to_s)
						end
						lk_Results['results'][ls_Band][ls_Peptide][li_MatchIndex]['snr'] = lk_Value
					end
				end
			end
		end
		
		li_ChuckedOutBecauseOfTimeDifference = 0
		li_ChuckedOutBecauseOfNoMs2Identification = 0
		lk_UnidentifiedPeptides = Set.new
		lk_TooHighTimeDifferencePeptides = Set.new
		
		# chuck out quantitation events that have no corresponding MS2 identification event
		if @param[:useMaxIdentificationQuantitationTimeDifference]
			puts "Quantiation events before RT filtering: #{li_QuantiationEventCount}."
			lk_Results['results'].each do |ls_Spot, lk_SpotResults|
				next unless lk_SpotResults
				lk_SpotResults.keys.each do |ls_Peptide|
					lk_Results['results'][ls_Spot][ls_Peptide].reject! do |lk_Hit|
						puts lk_Hit.to_yaml if ls_Peptide == 'WLQYSEVIHAR'
						lb_RejectThis = true
						lb_RejectedDueToTimeDifference = false
						if lk_PeptideHash && lk_PeptideHash.include?(ls_Peptide)
							lk_PeptideHash[ls_Peptide][:scans].each do |ls_Scan|
								puts lk_ScanHash[ls_Scan].to_yaml if ls_Peptide == 'WLQYSEVIHAR'
								# ls_Spot comes from SimQuant
								ls_Ms2Spot = ls_Scan.split('.').first
								lb_RejectThis = false if ((lk_ScanHash[ls_Scan][:retentionTime] - lk_Hit['retentionTime']).abs <= @param[:maxIdentificationQuantitationTimeDifference]) && (ls_Spot == ls_Ms2Spot)
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
			end
		end

		if (li_ChuckedOutBecauseOfNoMs2Identification > 0) || (li_ChuckedOutBecauseOfTimeDifference > 0)
			puts 'Attention: Some quantitation events have been removed.'
			puts "...because there was no MS2 identification: #{li_ChuckedOutBecauseOfNoMs2Identification}" if li_ChuckedOutBecauseOfNoMs2Identification > 0
			puts "...because the SimQuant/MS2 RT difference was too high: #{li_ChuckedOutBecauseOfTimeDifference}" if li_ChuckedOutBecauseOfTimeDifference > 0
		else
			puts "No quantitation events have been removed." if @param[:useMaxIdentificationQuantitationTimeDifference]
		end
		
		# chuck out empty entries
		lk_Results['results'].each do |ls_Spot, lk_SpotResults|
			unless lk_SpotResults
				lk_Results['results'].delete(ls_Spot)
				next
			end
			lk_SpotResults.keys.each do |ls_Peptide|
				lk_Results['results'][ls_Spot].delete(ls_Peptide) if lk_SpotResults[ls_Peptide].empty?
			end
			lk_Results['results'].delete(ls_Spot) if (!lk_Results['results'][ls_Spot]) || lk_Results['results'][ls_Spot].empty?
		end
		

		if ((!lk_Results.include?('results')) || (lk_Results['results'].class != Hash) || (lk_Results['results'].size == 0))
			puts 'No peptides could be quantified.'
		else
			if @output[:proteinCsv]
				File.open(@output[:proteinCsv], 'w') do |lk_Out|
					lk_Out.puts "Band / Protein / Peptide;count;ratio mean;ratio sd;snr mean;snr sd"
					
					lk_QuantifiedPeptides = Array.new
					lk_Results['results'].each { |ls_Spot, lk_SpotResults| lk_QuantifiedPeptides += lk_SpotResults.keys }
					lk_MatchedPeptides = lk_QuantifiedPeptides.select do |ls_Peptide|
						lk_PeptideInProtein.include?(ls_Peptide) && lk_PeptideInProtein[ls_Peptide].size == 1
					end
					
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
					lk_Results['results'].keys.each do |ls_Spot|
						lk_PeptideMergedResults[ls_Spot] = Hash.new
						lk_Results['results'][ls_Spot].keys.each do |ls_Peptide|
							lk_PeptideMergedResults[ls_Spot][ls_Peptide] = Hash.new
							# determine merged ratio/snr
							lk_MergedRatio = Array.new
							lk_MergedSnr = Array.new
							lk_Results['results'][ls_Spot][ls_Peptide].each do |lk_Scan|
								lk_MergedRatio.push(lk_Scan['ratio'])
								lk_MergedSnr.push(lk_Scan['snr'])
							end
							ld_MergedRatioMean, ld_MergedRatioSd = meanAndStandardDeviation(lk_MergedRatio)
							ld_MergedSnrMean, ld_MergedSnrSd = meanAndStandardDeviation(lk_MergedSnr)
							lk_PeptideMergedResults[ls_Spot][ls_Peptide][:ratioMean] = ld_MergedRatioMean
							lk_PeptideMergedResults[ls_Spot][ls_Peptide][:ratioSd] = ld_MergedRatioSd
							lk_PeptideMergedResults[ls_Spot][ls_Peptide][:snrMean] = ld_MergedSnrMean
							lk_PeptideMergedResults[ls_Spot][ls_Peptide][:snrSd] = ld_MergedSnrSd
							lk_PeptideMergedResults[ls_Spot][ls_Peptide][:count] = lk_MergedRatio.size
						end
					end
					
					# determine merged results for each spot/protein
					lk_ProteinMergedResults = Hash.new
					lk_Results['results'].keys.each do |ls_Spot|
						lk_ProteinMergedResults[ls_Spot] = Hash.new
						lk_Proteins = lk_MatchedPeptides.select { |x| lk_Results['results'][ls_Spot].keys.include?(x) }.collect do |ls_Peptide|
							lk_PeptideInProtein[ls_Peptide].keys.first
						end
						lk_Proteins.sort! { |a, b| String::natcmp(a, b) }
						lk_Proteins.uniq!
						
						lk_Proteins.each do |ls_Protein|
							lk_ProteinMergedResults[ls_Spot][ls_Protein] = Hash.new
							# determine merged ratio/snr
							lk_MergedRatio = Array.new
							lk_MergedSnr = Array.new
							lk_PeptidesForProtein[ls_Protein].each do |ls_Peptide|
								next unless lk_Results['results'][ls_Spot].keys.include?(ls_Peptide)
								lk_Results['results'][ls_Spot][ls_Peptide].each do |lk_Scan|
									lk_MergedRatio.push(lk_Scan['ratio'])
									lk_MergedSnr.push(lk_Scan['snr'])
								end
							end
							ld_MergedRatioMean, ld_MergedRatioSd = meanAndStandardDeviation(lk_MergedRatio)
							ld_MergedSnrMean, ld_MergedSnrSd = meanAndStandardDeviation(lk_MergedSnr)
							lk_ProteinMergedResults[ls_Spot][ls_Protein][:ratioMean] = ld_MergedRatioMean
							lk_ProteinMergedResults[ls_Spot][ls_Protein][:ratioSd] = ld_MergedRatioSd
							lk_ProteinMergedResults[ls_Spot][ls_Protein][:snrMean] = ld_MergedSnrMean
							lk_ProteinMergedResults[ls_Spot][ls_Protein][:snrSd] = ld_MergedSnrSd
							lk_ProteinMergedResults[ls_Spot][ls_Protein][:count] = lk_MergedRatio.size
						end
					end
					
					unless lk_MatchedPeptides.empty?
						lk_Results['results'].keys.sort { |a, b| String::natcmp(a, b) }.each do |ls_Spot|
							lk_Out.puts "#{ls_Spot}"
							lk_Proteins = lk_MatchedPeptides.select { |x| lk_Results['results'][ls_Spot].keys.include?(x) }.collect do |ls_Peptide|
								lk_PeptideInProtein[ls_Peptide].keys.first
							end
							lk_Proteins.sort! { |a, b| String::natcmp(a, b) }
							lk_Proteins.uniq!
							
							lk_Proteins.each do |ls_Protein|
								lk_Out.puts "\"#{ls_Protein}\";#{lk_ProteinMergedResults[ls_Spot][ls_Protein][:count]};#{niceRatio(lk_ProteinMergedResults[ls_Spot][ls_Protein][:ratioMean])};#{lk_ProteinMergedResults[ls_Spot][ls_Protein][:ratioSd]};#{cutMax(lk_ProteinMergedResults[ls_Spot][ls_Protein][:snrMean])};#{cutMax(lk_ProteinMergedResults[ls_Spot][ls_Protein][:snrSd])}"
								lk_PeptidesForProtein[ls_Protein].each do |ls_Peptide|
									next unless lk_Results['results'][ls_Spot].keys.include?(ls_Peptide)
									lk_Out.puts "#{ls_Peptide};#{lk_PeptideMergedResults[ls_Spot][ls_Peptide][:count]};#{niceRatio(lk_PeptideMergedResults[ls_Spot][ls_Peptide][:ratioMean])};#{lk_PeptideMergedResults[ls_Spot][ls_Peptide][:ratioSd]};#{cutMax(lk_PeptideMergedResults[ls_Spot][ls_Peptide][:snrMean])};#{cutMax(lk_PeptideMergedResults[ls_Spot][ls_Peptide][:snrSd])}"
								end
							end
						end
					end
				end
			end
			if @output[:yamlReport]
				File.open(@output[:yamlReport], 'w') do |lk_Out|
						lk_Out.puts lk_Results.to_yaml
				end
			end
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
					lk_Results['results'].each do |ls_Spot, lk_SpotResults| 
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
					lk_Results['results'].keys.each do |ls_Spot|
						lk_PeptideMergedResults[ls_Spot] = Hash.new
						next unless lk_Results['results'][ls_Spot]
						lk_Results['results'][ls_Spot].keys.each do |ls_Peptide|
							lk_PeptideMergedResults[ls_Spot][ls_Peptide] = Hash.new
							# determine merged ratio/snr
							lk_MergedSnr = Array.new
							lk_MergedRatio = Array.new
							lf_MergedUnlabeledAmount = 0.0
							lf_MergedLabeledAmount = 0.0
							
							lk_Results['results'][ls_Spot][ls_Peptide].each do |lk_Scan|
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
							lk_PeptideMergedResults[ls_Spot][ls_Peptide][:shinyNewRatioMean] = lf_MergedUnlabeledAmount / lf_MergedLabeledAmount
							lk_PeptideMergedResults[ls_Spot][ls_Peptide][:ratioMeanPrint] = niceRatio(ld_MergedRatioMean)
							lk_PeptideMergedResults[ls_Spot][ls_Peptide][:ratioSdPrint] = lk_MergedSnr.size == 1 ? '&ndash;' : sprintf('%1.2f', ld_MergedRatioSd)
						end
					end
					
					# determine merged results for each spot/protein
					lk_ProteinMergedResults = Hash.new
					lk_Results['results'].keys.each do |ls_Spot|
						lk_ProteinMergedResults[ls_Spot] = Hash.new
						lk_Proteins = lk_MatchedPeptides.select { |x| lk_Results['results'][ls_Spot].keys.include?(x) }.collect do |ls_Peptide|
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
								next unless lk_Results['results'][ls_Spot].keys.include?(ls_Peptide)
								lk_Results['results'][ls_Spot][ls_Peptide].each do |lk_Scan|
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
							lk_ProteinMergedResults[ls_Spot][ls_Protein][:shinyNewRatioMean] = lf_MergedUnlabeledAmount / lf_MergedLabeledAmount
							lk_ProteinMergedResults[ls_Spot][ls_Protein][:ratioMeanPrint] = niceRatio(ld_MergedRatioMean)
							lk_ProteinMergedResults[ls_Spot][ls_Protein][:ratioSdPrint] = lk_MergedSnr.size == 1 ? '&ndash;' : sprintf('%1.2f', ld_MergedRatioSd)
						end
					end
					
					unless lk_MatchedPeptides.empty?
						lk_Out.puts "<h2 id='header-quantified-proteins'>Quantified proteins</h2>"
						
						lk_Out.puts "<table>"
						lk_Out.puts "<tr><th rowspan='2'>Band / Protein / Peptides</th><th rowspan='2'>Elution profile</th><th rowspan='2'>Peptide location in protein</th><th rowspan='2'>Count</th><th colspan='2'>Ratio</th></tr>"
						lk_Out.puts "<tr><th>mean</th><th>sd</th></tr>"
						
						lk_Results['results'].keys.sort { |a, b| String::natcmp(a, b) }.each do |ls_Spot|
							lk_Out.puts "<tr><td style='border: none' colspan='6'></td></tr>"
							lk_Out.puts "<tr style='background-color: #ddd;'>"
							lk_Out.puts "<td colspan='6'><b>#{ls_Spot}</b></td>"
							lk_Out.puts "</tr>"
							
							lk_Proteins = lk_MatchedPeptides.select { |x| lk_Results['results'][ls_Spot].keys.include?(x) }.collect do |ls_Peptide|
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
									next unless lk_Results['results'][ls_Spot].keys.include?(ls_Peptide)
									lk_Out.puts "<tr>"
									li_Width = 256
									ls_PeptideInProteinSvg = ''
									
									lk_Out.puts "<td><a href='##{ls_Spot}-#{ls_Peptide}'>#{ls_Peptide}</a></td>"
									lk_Out.puts '<td>'
									if (@param[:showElutionProfile])
										ls_Svg = "<svg style='margin-left: 4px;' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' xmlns:ev='http://www.w3.org/2001/xml-events' version='1.1' baseProfile='full' width='#{li_Width}px' height='16px'><rect x='0' y='0' width='#{li_Width}' height='16px' fill='#ddd' />"
										lk_Results['results'][ls_Spot][ls_Peptide].each do |lk_Hit|
											ls_Svg += "<line x1='#{lk_Hit['retentionTime'] / 60.0 * li_Width}' y1='8' x2='#{lk_Hit['retentionTime'] / 60.0 * li_Width}' y2='16' fill='none' stroke='#0080ff' stroke-width='1' />"
										end
										if (lk_PeptideHash)
											lk_PeptideHash[ls_Peptide][:scans].each do |ls_Scan|
												ld_RetentionTime = lk_ScanHash[ls_Scan][:retentionTime]
												ls_Svg += "<line x1='#{ld_RetentionTime / 60.0 * li_Width}' y1='0' x2='#{ld_RetentionTime / 60.0 * li_Width}' y2='8' fill='none' stroke='#000' stroke-width='1' />"
											end
										end
=begin										
										lk_PeptideInProtein[ls_Peptide][lk_PeptideInProtein[ls_Peptide].keys.first].each do |lk_Line|
											lf_BarWidth = lk_Line['length'].to_f / lk_Line['proteinLength'] * li_Width
											lf_BarWidth = 2.0 if lf_BarWidth < 2.0
											ls_Svg += "<line x1='#{lk_Line['start'].to_f / lk_Line['proteinLength'] * li_Width}' y1='1.5' x2='#{lk_Line['start'].to_f / lk_Line['proteinLength'] * li_Width + lf_BarWidth}' y2='1.5' fill='none' stroke='#000' stroke-width='2' />"
										end
=end										
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
=begin					
						lk_Results['results'].keys.sort { |a, b| String::natcmp(a, b) }.each do |ls_Spot|
							lk_Out.puts "<tr><td style='border: none' colspan='6'></td></tr>"
							lk_Out.puts "<tr style='background-color: #ddd;'>"
							lk_Out.puts "<td colspan='5'><b>#{ls_Spot}</b></td>"
							lk_Out.puts "</tr>"
							
							lk_Results['results'][ls_Spot]['proteins'].keys.sort { |a, b| String::natcmp(a, b) }.each do |ls_Protein|
								lk_Out.puts "<tr><td style='border: none' colspan='6'></td></tr>"
								lk_Out.puts "<tr style='baclk_PeptideMergedResultskground-color: #eee;'>"
								lk_Out.puts "<td>#{ls_Protein}</td>"
								lk_Out.puts "<td style='text-align: right;'>#{cutMax(0.0)}</td>"
								lk_Out.puts "<td style='text-align: right;'>#{cutMax(0.0)}</td>"
								lk_Out.puts "<td style='text-align: right;'>#{cutMax(0.0)}</td>"
								lk_Out.puts "<td style='text-align: right;'>#{cutMax(0.0)}</td>"
								lk_Out.puts "</tr>"
								
								lk_Results['results'][ls_Spot]['proteins'][ls_Protein]['peptides'].keys.sort do |a, b| 
									lk_Results['results'][ls_Spot]['proteins'][ls_Protein]['peptides'][a].first['start'] <=>
									lk_Results['results'][ls_Spot]['proteins'][ls_Protein]['peptides'][b].first['start']
								end.each do |ls_Peptide|
									lk_Out.puts "<tr>"
									li_Width = 256
									ls_PeptideInProteinSvg = "<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' xmlns:ev='http://www.w3.org/2001/xml-events' version='1.1' baseProfile='full' width='#{li_Width}px' height='3px'><line x1='0' y1='1.5' x2='#{li_Width}' y2='1.5' fill='none' stroke='#aaa' stroke-width='1.5' />"
									lk_Results['results'][ls_Spot]['proteins'][ls_Protein]['peptides'][ls_Peptide].each do |lk_Line|
										lf_BarWidth = lk_Line['length'].to_f / lk_Line['proteinLength'] * li_Width
										lf_BarWidth = 2.0 if lf_BarWidth < 2.0
										ls_PeptideInProteinSvg += "<line x1='#{lk_Line['start'].to_f / lk_Line['proteinLength'] * li_Width}' y1='1.5' x2='#{lk_Line['start'].to_f / lk_Line['proteinLength'] * li_Width + lf_BarWidth}' y2='1.5' fill='none' stroke='#000' stroke-width='2' />"
									end
									ls_PeptideInProteinSvg += "</svg>"
									
									lk_Out.puts "<td><div style='float: right'>#{ls_PeptideInProteinSvg}</div> #{ls_Peptide}</td>"
									lk_Out.puts "<td style='text-align: right;'>#{cutMax(0.0)}</td>"
									lk_Out.puts "<td style='text-align: right;'>#{cutMax(0.0)}</td>"
									lk_Out.puts "<td style='text-align: right;'>#{cutMax(0.0)}</td>"
									lk_Out.puts "<td style='text-align: right;'>#{cutMax(0.0)}</td>"
									lk_Out.puts "</tr>"
								end
							end
						end
						
=end
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
					lk_Results['results'].keys.sort { |a, b| String::natcmp(a, b) }.each do |ls_Spot|
						lk_Out.puts "<tr><td style='border: none' colspan='5'></td></tr>"
						lk_Out.puts "<tr style='background-color: #ddd;'>"
						lk_Out.puts "<td colspan='5'><b>#{ls_Spot}</b></td>"
						lk_Out.puts "</tr>"
						
						next unless lk_Results['results'][ls_Spot]
						lk_Results['results'][ls_Spot].keys.sort { |a, b| String::natcmp(a, b) }.each do |ls_Peptide|
							lk_Out.puts "<tr><td style='border: none' colspan='5'></td></tr>"
							lk_Out.puts "<tr style='background-color: #eee;' id='#{ls_Spot}-#{ls_Peptide}'><td id='peptide-#{ls_Peptide}'><b>#{ls_Peptide}</b></td>"
							lk_Out.puts "<td style='text-align: right;'>#{lk_PeptideMergedResults[ls_Spot][ls_Peptide][:count]}</td>"
							lk_Out.puts "<td style='text-align: right;'>#{lk_PeptideMergedResults[ls_Spot][ls_Peptide][:ratioMeanPrint]}</td>"
							lk_Out.puts "<td style='text-align: right;'>#{lk_PeptideMergedResults[ls_Spot][ls_Peptide][:ratioSdPrint]}</td>"
							lk_Out.puts "<td style='text-align: right;'>&ndash;</td>"
							lk_Out.puts "</tr>"
							
							lk_Scans = lk_Results['results'][ls_Spot][ls_Peptide]
							lk_Scans.sort! { |a, b| a['retentionTime'] <=> b['retentionTime'] }
							lk_Scans.each do |lk_Scan|
								lk_Out.puts "<tr><td style='border: none' colspan='5'></td></tr>" if @param[:includeSpectra]
								lk_Out.puts "<tr><td>scan ##{lk_Scan['id']} (charge #{lk_Scan['charge']}+)</td>"
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
		end
	end
end

lk_Object = SimQuant.new

