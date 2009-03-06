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

def medianAndCo(ak_Values)
	lk_Values = ak_Values.sort
	lk_Result = Array.new
	[0, 25, 50, 75, 100].each do |li_P|
		li_Position = (lk_Values.size - 1) * li_P
		lf_Value = lk_Values[li_Position / 100]
		lf_Value = (lf_Value + lk_Values[li_Position / 100 + 1]) * 0.5 if (li_Position % 100 != 0)
		lk_Result << lf_Value
	end
	return lk_Result
end

def mean(ak_Values)
	lf_Mean = 0.0
	ak_Values.each { |x| lf_Mean += x }
	return lf_Mean / ak_Values.size
end

class CompareOmssaSimQuant < ProteomaticScript
	def run()
		lk_RunResults = Hash.new
		# compare multiple OMSSA results
		@input[:psmFile].each do |ls_Path|
			ls_Key = File::basename(ls_Path).sub('.csv', '')
			lk_RunResults[ls_Key] = loadPsm(ls_Path)
		end
		
		lk_SimQuantResults = Hash.new
		@input[:yamlFile].each do |ls_Path|
			ls_Key = File::basename(ls_Path).sub('.yaml', '')
			lk_SimQuantResults[ls_Key] = YAML::load_file(ls_Path)['results']
		end
		
		lk_NormalizationProteins = ['jgi|Chlre3|153678|Chlre2_kg.scaffold_66000007 {LHCA3} light-harvesting chlorophyll-a/b protein of photosystem I (Type III)',
			'Chlre3|120177|e_gwW.36.28.1',
			'K000554.2|DAA00922.1|28269744|']

		lk_QuantProteinHash = Hash.new
		lk_QuantPeptideHash = Hash.new
		lk_SimQuantResults.each do |ls_Key, lk_Results|
			lk_Results.each do |ls_Spot, lk_SpotResults|
				ls_SpotId = ls_Spot.sub('_new', '').split('_').last
				lk_SpotResults.each do |ls_Peptide, lk_PeptideResults|
					lk_Proteins = lk_RunResults[ls_Key][:peptideHash][ls_Peptide][:proteins]
					next if lk_Proteins.size > 1
					ls_Protein = lk_Proteins.keys.first
					#ls_Protein.slice!(0, ls_Protein.index('.fasta;') + 7) if (ls_Protein.include?('.fasta;'))
					lk_QuantPeptideHash[ls_Peptide] ||= Hash.new
					lk_QuantPeptideHash[ls_Peptide][:count] ||= 0
					lk_QuantPeptideHash[ls_Peptide][:occurences] ||= Hash.new
					lk_QuantPeptideHash[ls_Peptide][:occurences][ls_Key] ||= Hash.new
					lk_QuantPeptideHash[ls_Peptide][:occurences][ls_Key][:count] ||= 0
					lk_QuantPeptideHash[ls_Peptide][:occurences][ls_Key][:spots] ||= Hash.new
					lk_QuantPeptideHash[ls_Peptide][:ratios] ||= Hash.new
					lk_QuantPeptideHash[ls_Peptide][:spotRatios] ||= Hash.new

					lk_QuantProteinHash[ls_Protein] ||= Hash.new
					lk_QuantProteinHash[ls_Protein][:count] ||= 0
					lk_QuantProteinHash[ls_Protein][:occurences] ||= Hash.new
					lk_QuantProteinHash[ls_Protein][:occurences][ls_Key] ||= Hash.new
					lk_QuantProteinHash[ls_Protein][:occurences][ls_Key][:count] ||= 0
					lk_QuantProteinHash[ls_Protein][:occurences][ls_Key][:spots] ||= Hash.new
					lk_QuantProteinHash[ls_Protein][:ratios] ||= Hash.new
					lk_QuantProteinHash[ls_Protein][:spotRatios] ||= Hash.new
					lk_PeptideResults.each do |lk_Hit|
						lk_QuantPeptideHash[ls_Peptide][:occurences][ls_Key][:spots][ls_SpotId] ||= 0
						lk_QuantPeptideHash[ls_Peptide][:occurences][ls_Key][:spots][ls_SpotId] += 1
						lk_QuantPeptideHash[ls_Peptide][:occurences][ls_Key][:count] += 1
						lk_QuantPeptideHash[ls_Peptide][:count] += 1
						lk_QuantPeptideHash[ls_Peptide][:ratios][ls_Key] ||= Array.new
						lk_QuantPeptideHash[ls_Peptide][:ratios][ls_Key] << lk_Hit['ratio']
						lk_QuantPeptideHash[ls_Peptide][:spotRatios][ls_Key] ||= Hash.new
						lk_QuantPeptideHash[ls_Peptide][:spotRatios][ls_Key][ls_SpotId] ||= Array.new
						lk_QuantPeptideHash[ls_Peptide][:spotRatios][ls_Key][ls_SpotId] << lk_Hit['ratio']
						
						lk_QuantProteinHash[ls_Protein][:occurences][ls_Key][:spots][ls_SpotId] ||= 0
						lk_QuantProteinHash[ls_Protein][:occurences][ls_Key][:spots][ls_SpotId] += 1
						lk_QuantProteinHash[ls_Protein][:occurences][ls_Key][:count] += 1
						lk_QuantProteinHash[ls_Protein][:count] += 1
						lk_QuantProteinHash[ls_Protein][:ratios][ls_Key] ||= Array.new
						lk_QuantProteinHash[ls_Protein][:ratios][ls_Key] << lk_Hit['ratio']
						lk_QuantProteinHash[ls_Protein][:spotRatios][ls_Key] ||= Hash.new
						lk_QuantProteinHash[ls_Protein][:spotRatios][ls_Key][ls_SpotId] ||= Array.new
						lk_QuantProteinHash[ls_Protein][:spotRatios][ls_Key][ls_SpotId] << lk_Hit['ratio']
					end
				end
			end
		end

		lk_CsvOut = File.open(@output[:csvReport], 'w') if @output[:csvReport]
		if @output[:htmlReport]
			File.open(@output[:htmlReport], 'w') do |lk_Out|
				lk_RunKeys = lk_RunResults.keys.sort { |x, y| String::natcmp(x, y) }
				
				lk_Out.puts '<html>'
				lk_Out.puts '<head>'
				lk_Out.puts '<title>OMSSA Comparison Report</title>'
				lk_Out.puts '<style type=\'text/css\'>'
				lk_Out.puts 'body {font-family: Verdana; font-size: 10pt;}'
				lk_Out.puts 'h1 {font-size: 14pt;}'
				lk_Out.puts 'h2 {font-size: 12pt; border-top: 1px solid #888; border-bottom: 1px solid #888; padding-top: 0.2em; padding-bottom: 0.2em; background-color: #e8e8e8; }'
				lk_Out.puts 'h3 {font-size: 10pt; }'
				lk_Out.puts 'h4 {font-size: 10pt; font-weight: normal;}'
				lk_Out.puts 'ul {padding-left: 0;}'
				lk_Out.puts 'ol {padding-left: 0;}'
				lk_Out.puts 'li {margin-left: 2em;}'
				lk_Out.puts '.default { }'
				lk_Out.puts '.nonDefault { background-color: #ada;}'
				lk_Out.puts 'table {border-collapse: collapse;} '
				lk_Out.puts 'table tr {text-align: left; font-size: 10pt;}'
				lk_Out.puts 'table th, td {vertical-align: top; border: 1px solid #888; padding: 0.2em;}'
				lk_Out.puts 'table th {font-weight: bold;}'
				lk_Out.puts '.gpf-confirm { background-color: #aed16f; }'
				lk_Out.puts '.toggle { cursor: pointer; text-decoration: underline; color: #aaa; }'
				lk_Out.puts '.toggle:hover { color: #000; }'
				lk_Out.puts '</style>'
				lk_Out.puts "<script type='text/javascript'>"
				lk_Out.puts "/*<![CDATA[*/"
				lk_Out.puts "function toggle(as_Name, as_Display) {"
				lk_Out.puts "lk_Elements = document.getElementsByClassName(as_Name);"
				lk_Out.puts "for (var i = 0; i < lk_Elements.length; ++i)"
				lk_Out.puts "lk_Elements[i].style.display = lk_Elements[i].style.display == 'none' ? as_Display : 'none';"
				lk_Out.puts "}"
				lk_Out.puts "/*]]>*/"
				lk_Out.puts "</script>"
				lk_Out.puts '</head>'
				lk_Out.puts '<body>'
				lk_Out.puts '<h1>OMSSA Comparison Report</h1>'
			
				lk_Out.puts '<table>'
				lk_Out.puts "<tr><th></th><th>Protein/Peptide</th>#{lk_RunKeys.collect { |x| '<th>' + x + '</th>'}.join('') }</tr>"
				# collect proteins from all runs
				lk_AllProteinsSet = Set.new
				lk_RunKeys.each { |ls_Key| lk_AllProteinsSet.merge(lk_RunResults[ls_Key][:proteins].keys) }
				lk_Proteins = lk_AllProteinsSet.to_a.sort { |x, y| String::natcmp(x, y) }
				
				lk_ProteinSampleCount = Hash.new
				lk_Proteins.each do |ls_Protein|
					li_Sum = 0
					lk_SampleSet = Set.new
					lk_RunKeys.each do |ls_Key|
						li_This = 0
						li_This = lk_QuantProteinHash[ls_Protein][:occurences][ls_Key][:count] if lk_QuantProteinHash[ls_Protein] && lk_QuantProteinHash[ls_Protein][:occurences][ls_Key]
						li_Sum += li_This
						lk_SampleSet << ls_Key[0, 2] if li_This > 0
					end
					lk_ProteinSampleCount[ls_Protein] = lk_SampleSet.size unless lk_SampleSet.empty?
				end
				
				lk_NormalizationValues = Hash.new
				
				# determine normalization values
				lk_ProteinSampleCount.keys.each do |ls_Protein|
					lb_IsNormalizationProtein = false
					lk_NormalizationProteins.each do |x|
						lb_IsNormalizationProtein = true if (ls_Protein.include?(x))
					end
					next unless lb_IsNormalizationProtein

					# auto pick bands
					lk_SpectralCountsForBand = Hash.new
					lk_RunKeys.each do |ls_Key|
						li_Count = 0
						#li_Count = lk_RunResults[ls_Key][:proteins][ls_Protein][:spectralCount] if lk_RunResults[ls_Key][:proteins].has_key?(ls_Protein)
						li_Count = lk_RunResults[ls_Key][:spectralCounts][:proteins][ls_Protein][:total] if lk_RunResults[ls_Key][:proteins].has_key?(ls_Protein)
						lk_Spots = nil
						lk_Spots = lk_RunResults[ls_Key][:spectralCounts][:proteins][ls_Protein].keys if lk_RunResults[ls_Key][:spectralCounts][:proteins][ls_Protein]
						if lk_Spots && (!lk_Spots.empty?)
							lk_Spots.reject! { |x| x == :total }
							lk_Spots.collect! do |x|
								x.sub('_new', '').split('_').last
							end
							# we now have key and spots
						end
						lk_Spots ||= []
						if lk_QuantProteinHash[ls_Protein]
							if lk_QuantProteinHash[ls_Protein][:occurences][ls_Key]
								lk_QuantProteinHash[ls_Protein][:occurences][ls_Key][:spots].keys.sort.each do |ls_Spot|
									lk_SpectralCountsForBand[ls_Spot] ||= 0
									lk_SpectralCountsForBand[ls_Spot] += lk_QuantProteinHash[ls_Protein][:occurences][ls_Key][:spots][ls_Spot]
								end
							end
						end
					end
					
					li_BestBandAmount = 0
					ls_BestBand = lk_SpectralCountsForBand.keys.first
					lk_SpectralCountsForBand.each do |ls_Band, li_Amount|
						if (li_Amount > li_BestBandAmount)
							li_BestBandAmount = li_Amount
							ls_BestBand = ls_Band
						end
					end
					li_BestBand = ls_BestBand.to_i
					
					lk_QuantProteinHash[ls_Protein][:ratios].keys.sort.each do |ls_Key|
						lk_QuantProteinHash[ls_Protein][:spotRatios][ls_Key].keys.sort.each do |ls_Spot|
							next unless (ls_Spot.to_i - li_BestBand).abs < 2
							ls_Sample = ls_Key[0, 2]
							lk_NormalizationValues[ls_Sample] ||= Array.new
							lk_NormalizationValues[ls_Sample] << lk_QuantProteinHash[ls_Protein][:spotRatios][ls_Key][ls_Spot]
						end
					end
				end
				
				lk_NormalizationValues.keys.sort.each do |ls_Sample|
					lk_NormalizationValues[ls_Sample].flatten!
					lk_NormalizationValues[ls_Sample] = medianAndCo(lk_NormalizationValues[ls_Sample])[2]
				end
				
				puts lk_NormalizationValues.to_yaml
				
				if (lk_CsvOut)
					lk_CsvOut.puts "Protein;Sample count;Quantitations;P0;P25;P50;P75;P100"
				end
				# do some work
				lk_ProteinSampleCount.keys.sort do |a, b| 
					(lk_ProteinSampleCount[b] == lk_ProteinSampleCount[a]) ?
						lk_QuantProteinHash[b][:count] <=> lk_QuantProteinHash[a][:count] :
						lk_ProteinSampleCount[b] <=> lk_ProteinSampleCount[a]
				end.each do |ls_Protein|
					next if lk_QuantProteinHash[ls_Protein][:count] < 3
					ls_Color = '#eee'
					lb_IsNormalizationProtein = false
					lk_NormalizationProteins.each do |x|
						lb_IsNormalizationProtein = true if (ls_Protein.include?(x))
					end
					ls_Color = '#a02' if lb_IsNormalizationProtein
					#next unless lb_IsNormalizationProtein

					# auto pick bands
					lk_SpectralCountsForBand = Hash.new
					lk_RunKeys.each do |ls_Key|
						li_Count = 0
						#li_Count = lk_RunResults[ls_Key][:proteins][ls_Protein][:spectralCount] if lk_RunResults[ls_Key][:proteins].has_key?(ls_Protein)
						li_Count = lk_RunResults[ls_Key][:spectralCounts][:proteins][ls_Protein][:total] if lk_RunResults[ls_Key][:proteins].has_key?(ls_Protein)
						lk_Spots = nil
						lk_Spots = lk_RunResults[ls_Key][:spectralCounts][:proteins][ls_Protein].keys if lk_RunResults[ls_Key][:spectralCounts][:proteins][ls_Protein]
						if lk_Spots && (!lk_Spots.empty?)
							lk_Spots.reject! { |x| x == :total }
							lk_Spots.collect! do |x|
								x.sub('_new', '').split('_').last
							end
							# we now have key and spots
						end
						lk_Spots ||= []
						if lk_QuantProteinHash[ls_Protein]
							if lk_QuantProteinHash[ls_Protein][:occurences][ls_Key]
								lk_QuantProteinHash[ls_Protein][:occurences][ls_Key][:spots].keys.sort.each do |ls_Spot|
									lk_SpectralCountsForBand[ls_Spot] ||= 0
									lk_SpectralCountsForBand[ls_Spot] += lk_QuantProteinHash[ls_Protein][:occurences][ls_Key][:spots][ls_Spot]
								end
							end
						end
					end
					
					li_BestBandAmount = 0
					ls_BestBand = nil
					lk_SpectralCountsForBand.each do |ls_Band, li_Amount|
						if ((ls_Band.to_i != 1) && (li_Amount > li_BestBandAmount))
							li_BestBandAmount = li_Amount
							ls_BestBand = ls_Band
						end
					end
					li_BestBand = ls_BestBand.to_i
					
					lk_Out.puts "<tr><td style='border: none' colspan='5'></td></tr>"
					lk_Out.print "<tr style='background-color: #{ls_Color};'><td>#{lk_ProteinSampleCount[ls_Protein]}</td><td>#{ls_Protein}"
					lk_Out.puts "<br />"
					lk_ProteinValues = Array.new
					lk_QuantProteinHash[ls_Protein][:ratios].keys.sort.each do |ls_Key|
						lk_QuantProteinHash[ls_Protein][:spotRatios][ls_Key].keys.sort.each do |ls_Spot|
							next unless (ls_Spot.to_i - li_BestBand).abs < 2
							lk_QuantProteinHash[ls_Protein][:spotRatios][ls_Key][ls_Spot].each do |x|
								lk_ProteinValues << x / lk_NormalizationValues[ls_Key[0, 2]]
							end
						end
					end
					lk_MedianAndCo = medianAndCo(lk_ProteinValues)
					lk_Out.puts "#{lk_MedianAndCo.collect { |x| sprintf('%1.2f', x)}.join(' ')} (#{lk_ProteinValues.size})"
					lk_Out.print "</td>"
					if (lk_CsvOut)
						lk_CsvOut.puts "\"#{ls_Protein}\";#{lk_ProteinSampleCount[ls_Protein]};#{lk_ProteinValues.size};#{lk_MedianAndCo.collect { |x| sprintf('%1.4f', x)}.join(';')}"
					end

					lk_RunKeys.each do |ls_Key|
						li_Count = 0
						#li_Count = lk_RunResults[ls_Key][:proteins][ls_Protein][:spectralCount] if lk_RunResults[ls_Key][:proteins].has_key?(ls_Protein)
						li_Count = lk_RunResults[ls_Key][:spectralCounts][:proteins][ls_Protein][:total] if lk_RunResults[ls_Key][:proteins].has_key?(ls_Protein)
						lk_Spots = nil
						lk_Spots = lk_RunResults[ls_Key][:spectralCounts][:proteins][ls_Protein].keys if lk_RunResults[ls_Key][:spectralCounts][:proteins][ls_Protein]
						if lk_Spots && (!lk_Spots.empty?)
							lk_Spots.reject! { |x| x == :total }
							lk_Spots.collect! do |x|
								x.sub('_new', '').split('_').last
							end
							# we now have key and spots
						end
						lk_Spots ||= []
						lk_Out.print "<td>"
						if lk_QuantProteinHash[ls_Protein]
							if lk_QuantProteinHash[ls_Protein][:occurences][ls_Key]
								lk_QuantProteinHash[ls_Protein][:occurences][ls_Key][:spots].keys.sort.each do |ls_Spot|
									ls_Bold = ''
									ls_Bold = 'font-weight: 900;' if (ls_Spot.to_i - li_BestBand).abs < 2
									lk_Out.print "<span style='white-space: nowrap; #{ls_Bold}'>#{ls_Spot} <span style='color: #aaa;'>(#{lk_QuantProteinHash[ls_Protein][:occurences][ls_Key][:spots][ls_Spot]})</span></span><br />"
								end
							end
						end
						lk_Out.puts "</td>"
					end
					
					lk_Out.print "</tr>"
					lk_Out.puts
					
					lk_PeptidesForProtein = Set.new
					lk_RunKeys.each do |ls_Key|
						lk_PeptidesForProtein += lk_RunResults[ls_Key][:proteins][ls_Protein] if lk_RunResults[ls_Key][:proteins][ls_Protein]
					end
					lk_PeptidesForProtein.to_a.sort.each do |ls_Peptide|
						li_Sum = 0
						lk_RunKeys.each do |ls_Key|
							li_Sum += lk_QuantPeptideHash[ls_Peptide][:occurences][ls_Key][:count] if lk_QuantPeptideHash[ls_Peptide] && lk_QuantPeptideHash[ls_Peptide][:occurences][ls_Key]
						end
						next if li_Sum == 0
						
						lk_Out.print "<tr><td></td><td>#{ls_Peptide}</td>"
						lk_RunKeys.each do |ls_Key|
							lk_Out.puts "<td>"
							if lk_QuantPeptideHash[ls_Peptide]
								if lk_QuantPeptideHash[ls_Peptide][:occurences][ls_Key]
									lk_QuantPeptideHash[ls_Peptide][:occurences][ls_Key][:spots].keys.sort.each do |ls_Spot|
										ls_Bold = ''
										ls_Bold = 'font-weight: 900;' if (ls_Spot.to_i - li_BestBand).abs < 2
										lk_Out.print "<span style='white-space: nowrap; #{ls_Bold}'>#{ls_Spot} <span style='color: #aaa;'>(#{lk_QuantPeptideHash[ls_Peptide][:occurences][ls_Key][:spots][ls_Spot]})</span></span><br />"
									end
								end
							end
							lk_Out.puts "</td>"
						end
						lk_Out.puts "</tr>"
					end
				end
				lk_Out.puts '</table>'
				
				
				lk_Out.puts '</body>'
				lk_Out.puts '</html>'
			end
		end
		lk_CsvOut.close if lk_CsvOut
	end
end

lk_Object = CompareOmssaSimQuant.new
