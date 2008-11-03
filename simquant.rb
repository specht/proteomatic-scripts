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
require 'include/externaltools'
require 'include/fasta'
require 'include/formats'
require 'include/misc'
require 'yaml'
require 'fileutils'

class SimQuant < ProteomaticScript
	def cutMax(af_Value, ai_Max = 10000, ai_Places = 2)
		return af_Value > ai_Max.to_f ? ">#{ai_Max}" : sprintf("%1.#{ai_Places}f", af_Value)
	end
	
	def run()
		lk_Peptides = @param[:peptides].split(%r{[,;\s/]+})
		lk_Peptides.reject! { |x| x.strip.empty? }
		
		lk_Peptides.uniq!
		lk_Peptides.collect! { |x| x.upcase }
		if lk_Peptides.empty? && @input[:peptideFiles].empty?
			puts 'Error: no peptides have been specified.'
			exit 1
		end
		
		ls_TempPath = tempFilename('simquant')
		ls_TempPath = '/flipbook/spectra/quantification/temp-simquant.7697.0'
		ls_YamlPath = File::join(ls_TempPath, 'out.yaml')
		ls_SvgPath = File::join(ls_TempPath, 'svg')
		FileUtils::mkpath(ls_TempPath)
		FileUtils::mkpath(ls_SvgPath)
		
		ls_Command = "\"#{ExternalTools::binaryPath('simquant.simquant')}\" --scanType #{@param[:scanType]} --isotopeCount #{@param[:isotopeCount]} --cropUpper #{@param[:cropUpper] / 100.0} --minSnr #{@param[:minSnr]} --maxOffCenter #{@param[:maxOffCenter] / 100.0} --maxTimeDifference #{@param[:maxTimeDifference]} --textOutput no --yamlOutput yes --yamlOutputTarget \"#{ls_YamlPath}\" --svgOutPath \"#{ls_SvgPath}\" --spectraFiles #{@input[:spectraFiles].collect {|x| '"' + x + '"'}.join(' ')} --peptides #{lk_Peptides.join(' ')} --peptideFiles #{@input[:peptideFiles].collect {|x| '"' + x + '"'}.join(' ')} --modelFiles #{@input[:modelFiles].collect {|x| '"' + x + '"'}.join(' ')}"
		#runCommand(ls_Command, true)
		
		lk_Results = YAML::load_file(ls_YamlPath)
		
		if ((!lk_Results.include?('results')) || (lk_Results['results'].class != Hash) || (lk_Results['results'].size == 0))
			puts 'No peptides could be quantified.'
		else
			if @output[:xhtmlReport]
				File.open(@output[:xhtmlReport], 'w') do |lk_Out|
					lk_Out.puts "<?xml version='1.0' encoding='utf-8' ?>"
					lk_Out.puts "<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.1//EN' 'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd'>"
					lk_Out.puts "<html xmlns='http://www.w3.org/1999/xhtml' xml:lang='de'>"
					lk_Out.puts '<head>'
					lk_Out.puts '<title>SimQuant Report</title>'
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
					lk_Out.puts 'table th, table td {vertical-align: top; border: 1px solid #888; padding: 0.2em;}'
					lk_Out.puts 'table tr.sub th, table tr.sub td {vertical-align: top; border: 1px dashed #888; padding: 0.2em;}'
					lk_Out.puts 'table th {font-weight: bold;}'
					lk_Out.puts '.gpf-confirm { background-color: #aed16f; }'
					lk_Out.puts '.toggle { padding: 0.2em; border: 1px solid #888; background-color: #f0f0f0; }'
					lk_Out.puts '.toggle:hover { cursor: pointer; border: 1px solid #000; background-color: #ddd; }'
					lk_Out.puts '.clickableCell { text-align: center; }'
					lk_Out.puts '.clickableCell:hover { cursor: pointer; }'
					lk_Out.puts '</style>'
=begin					
					lk_Out.puts "<script type='text/javascript'>"
					lk_Out.puts "<![CDATA["
					lk_Out.puts
					
					lk_ProteinForPeptide = Hash.new
					lk_Results['proteinResults'].keys.each do |ls_Protein|
						lk_Results['proteinResults'][ls_Protein]['peptides'].keys.each do |ls_Peptide|
							if (lk_ProteinForPeptide.include?(ls_Peptide))
								puts 'WARNING: Something went wrong. A peptide matches multiple proteins.'
							end
							lk_ProteinForPeptide[ls_Peptide] = ls_Protein
						end
					end
					
					# lk_ScanIndex: spot-scanid
					lk_ScanIndex = Hash.new
					# lk_PeptideIndex: peptide
					lk_PeptideIndex = Hash.new
					# lk_ProteinIndex: protein
					lk_ProteinIndex = Hash.new
					# lk_SpotIndex: spot
					lk_SpotIndex = Hash.new
					
					lk_Results['peptideResults'].keys.each do |ls_Peptide|
						lk_PeptideIndex[ls_Peptide] ||= lk_PeptideIndex.size.to_s
						lk_Results['peptideResults'][ls_Peptide]['spots'].keys.each do |ls_Spot|
							lk_SpotIndex[ls_Spot] ||= lk_SpotIndex.size.to_s
							lk_Results['peptideResults'][ls_Peptide]['spots'][ls_Spot]['scanResults'].each do |lk_Scan|
								lk_ScanIndex["#{ls_Spot}-#{lk_Scan['id']}"] ||= lk_ScanIndex.size.to_s
							end
						end
					end
					
					unless (lk_Results['proteinResults'].empty?)
						lk_Results['proteinResults'].keys.each do |ls_Protein|
							lk_ProteinIndex[ls_Protein] ||= lk_ProteinIndex.size.to_s
						end
					end
					
					# write ratio and SNR for every single scan result
					lk_Out.puts "gk_RatioHash = new Object();"
					lk_Out.puts "gk_SnrHash = new Object();"
					lk_Results['peptideResults'].keys.each do |ls_Peptide|
						lk_Results['peptideResults'][ls_Peptide]['spots'].keys.each do |ls_Spot|
							lk_Results['peptideResults'][ls_Peptide]['spots'][ls_Spot]['scanResults'].each do |lk_Scan|
								ls_Id = lk_ScanIndex["#{ls_Peptide}-#{ls_Spot}-#{lk_Scan['id']}-#{lk_Scan['charge']}"]
								lk_Out.puts "gk_RatioHash['#{ls_Id}'] = #{lk_Scan['ratio']};"
								lk_Out.puts "gk_SnrHash['#{ls_Id}'] = #{lk_Scan['snr']};"
							end
						end
					end
					lk_Out.puts
					
					# write which elements are affected when a scan is included/excluded
					lk_Out.puts "gk_AffectHash = new Object();"
					lk_Results['peptideResults'].keys.each do |ls_Peptide|
						lk_Results['peptideResults'][ls_Peptide]['spots'].keys.each do |ls_Spot|
							lk_Results['peptideResults'][ls_Peptide]['spots'][ls_Spot]['scanResults'].each do |lk_Scan|
								ls_Id = lk_ScanIndex["#{ls_Peptide}-#{ls_Spot}-#{lk_Scan['id']}-#{lk_Scan['charge']}"]
								lk_Out.puts "gk_AffectHash['#{ls_Id}'] = new Array();"
								lk_Out.puts "gk_AffectHash['#{ls_Id}'].push('#{lk_PeptideAndFileIndex[ls_Peptide + '-' + ls_Spot]}');"
								lk_Out.puts "gk_AffectHash['#{ls_Id}'].push('#{lk_PeptideIndex[ls_Peptide]}');"
								if (lk_ProteinForPeptide.include?(ls_Peptide))
									lk_Out.puts "gk_AffectHash['#{ls_Id}'].push('#{lk_ProteinIndex[lk_ProteinForPeptide[ls_Peptide]]}');"
								end
							end
						end
					end
					lk_Out.puts
					
					# write from which scan results each result is calculated
					lk_Out.puts "gk_CalculationHash = new Object();"
					lk_Results['peptideResults'].keys.each do |ls_Peptide|
						lk_Results['peptideResults'][ls_Peptide]['spots'].keys.each do |ls_Spot|
							# write peptide-file calculations
							ls_Id = lk_PeptideAndFileIndex["#{ls_Peptide}-#{ls_Spot}"]
							lk_Out.puts "gk_CalculationHash['#{ls_Id}'] = new Array();"
							lk_Results['peptideResults'][ls_Peptide]['spots'][ls_Spot]['scanResults'].each do |lk_Scan|
								lk_Out.puts "gk_CalculationHash['#{ls_Id}'].push('#{lk_ScanIndex["#{ls_Peptide}-#{ls_Spot}-#{lk_Scan['id']}-#{lk_Scan['charge']}"]}');"
							end
						end
						# write peptide calculations
						ls_Id = lk_PeptideIndex[ls_Peptide]
						lk_Out.puts "gk_CalculationHash['#{ls_Id}'] = new Array();"
						lk_Results['peptideResults'][ls_Peptide]['spots'].keys.each do |ls_Spot|
							lk_Results['peptideResults'][ls_Peptide]['spots'][ls_Spot]['scanResults'].each do |lk_Scan|
								lk_Out.puts "gk_CalculationHash['#{ls_Id}'].push('#{lk_ScanIndex["#{ls_Peptide}-#{ls_Spot}-#{lk_Scan['id']}-#{lk_Scan['charge']}"]}');"
							end
						end
					end
					# write protein calculations
					lk_Results['proteinResults'].keys.each do |ls_Protein|
						ls_Id = lk_ProteinIndex[ls_Protein]
						lk_Out.puts "gk_CalculationHash['#{ls_Id}'] = new Array();"
						lk_Results['proteinResults'][ls_Protein]['peptides'].keys.each do |ls_Peptide|
							lk_Results['peptideResults'][ls_Peptide]['spots'].keys.each do |ls_Spot|
								lk_Results['peptideResults'][ls_Peptide]['spots'][ls_Spot]['scanResults'].each do |lk_Scan|
									lk_Out.puts "gk_CalculationHash['#{ls_Id}'].push('#{lk_ScanIndex["#{ls_Peptide}-#{ls_Spot}-#{lk_Scan['id']}-#{lk_Scan['charge']}"]}');"
								end
							end
						end
					end
					lk_Out.puts
					
					lk_Out.puts "function toggle(as_Name) {"
					lk_Out.puts "lk_Elements = document.getElementsByClassName(as_Name);"
					lk_Out.puts "for (var i = 0; i < lk_Elements.length; ++i)"
					lk_Out.puts "lk_Elements[i].style.display = lk_Elements[i].style.display == 'none' ? 'table-row' : 'none';"
					lk_Out.puts "}"
					lk_Out.puts "function show(as_Name) {"
					lk_Out.puts "lk_Elements = document.getElementsByClassName(as_Name);"
					lk_Out.puts "for (var i = 0; i < lk_Elements.length; ++i)"
					lk_Out.puts "lk_Elements[i].style.display = 'table-row';"
					lk_Out.puts "}"
					lk_Out.puts "function hide(as_Name) {"
					lk_Out.puts "lk_Elements = document.getElementsByClassName(as_Name);"
					lk_Out.puts "for (var i = 0; i < lk_Elements.length; ++i)"
					lk_Out.puts "lk_Elements[i].style.display = 'none';"
					lk_Out.puts "}"
					lk_Out.puts "var gs_Red = '#f08682';"
					lk_Out.puts "var gs_Green = '#b1d28f';"
					lk_Out.puts "function cutMax(ad_Value) {"
					lk_Out.puts "  if (ad_Value > 10000.0)"
					lk_Out.puts "    return '>10000';"
					lk_Out.puts "  return ad_Value.toFixed(2);"
					lk_Out.puts "}"
					lk_Out.puts "function includeExclude(as_Name) {"
					lk_Out.puts "lk_Element = document.getElementById('checker-' + as_Name);"
					lk_Out.puts "  if (lk_Element.firstChild.data == 'included') {"
					lk_Out.puts "    lk_Element.style.backgroundColor = gs_Red;"
					lk_Out.puts "    lk_Element.firstChild.data = 'excluded'"
					lk_Out.puts "  } else {"
					lk_Out.puts "    lk_Element.style.backgroundColor = gs_Green;"
					lk_Out.puts "    lk_Element.firstChild.data = 'included'"
					lk_Out.puts "  }"
					lk_Out.puts "  for (var i = 0; i < gk_AffectHash[as_Name].length; ++i) {"
					lk_Out.puts "    var ls_Target = gk_AffectHash[as_Name][i];"
					lk_Out.puts "    var lk_RatioList = new Array();"
					lk_Out.puts "    var lk_SnrList = new Array();"
					lk_Out.puts "    for (var k = 0; k < gk_CalculationHash[ls_Target].length; ++k) {"
					lk_Out.puts "      var ls_Scan = gk_CalculationHash[ls_Target][k];"
					lk_Out.puts "      if (document.getElementById('checker-' + ls_Scan).firstChild.data == 'included') {"
					lk_Out.puts "        lk_RatioList.push(gk_RatioHash[ls_Scan]);"
					lk_Out.puts "        lk_SnrList.push(gk_SnrHash[ls_Scan]);"
					lk_Out.puts "      }"
					lk_Out.puts "    }"
					lk_Out.puts "    // calculate mean and standard deviation"
					lk_Out.puts "    var ls_RatioMean = '-';"
					lk_Out.puts "    var ls_RatioStdDev = '-';"
					lk_Out.puts "    var ls_SnrMean = '-';"
					lk_Out.puts "    var ls_SnrStdDev = '-';"
					lk_Out.puts "    if (lk_RatioList.length > 0) {"
					lk_Out.puts "      ld_RatioMean = 0.0;"
					lk_Out.puts "      ld_RatioStdDev = 0.0;"
					lk_Out.puts "      for (var k = 0; k < lk_RatioList.length; ++k)"
					lk_Out.puts "        ld_RatioMean += lk_RatioList[k];"
					lk_Out.puts "      ld_RatioMean /= lk_RatioList.length;"
					lk_Out.puts "      for (var k = 0; k < lk_RatioList.length; ++k)"
					lk_Out.puts "        ld_RatioStdDev += Math.pow(lk_RatioList[k] - ld_RatioMean, 2.0);"
					lk_Out.puts "      ld_RatioStdDev /= lk_RatioList.length;"
					lk_Out.puts "      ld_RatioStdDev = Math.sqrt(ld_RatioStdDev);"
					lk_Out.puts "      ls_RatioMean = cutMax(ld_RatioMean)"
					lk_Out.puts "      ls_RatioStdDev = cutMax(ld_RatioStdDev);"
					lk_Out.puts "      ld_SnrMean = 0.0;"
					lk_Out.puts "      ld_SnrStdDev = 0.0;"
					lk_Out.puts "      for (var k = 0; k < lk_SnrList.length; ++k)"
					lk_Out.puts "        ld_SnrMean += lk_SnrList[k];"
					lk_Out.puts "      ld_SnrMean /= lk_SnrList.length;"
					lk_Out.puts "      for (var k = 0; k < lk_SnrList.length; ++k)"
					lk_Out.puts "        ld_SnrStdDev += Math.pow(lk_SnrList[k] - ld_SnrMean, 2.0);"
					lk_Out.puts "      ld_SnrStdDev /= lk_SnrList.length;"
					lk_Out.puts "      ld_SnrStdDev = Math.sqrt(ld_SnrStdDev);"
					lk_Out.puts "      ls_SnrMean = cutMax(ld_SnrMean)"
					lk_Out.puts "      ls_SnrStdDev = cutMax(ld_SnrStdDev);"
					lk_Out.puts "    }"
					lk_Out.puts "    lk_Elements = document.getElementsByClassName('ratio-m-' + ls_Target);"
					lk_Out.puts "    for (var k = 0; k < lk_Elements.length; ++k) lk_Elements[k].firstChild.data = ls_RatioMean;"
					lk_Out.puts "    lk_Elements = document.getElementsByClassName('ratio-s-' + ls_Target);"
					lk_Out.puts "    for (var k = 0; k < lk_Elements.length; ++k) lk_Elements[k].firstChild.data = ls_RatioStdDev;"
					lk_Out.puts "    lk_Elements = document.getElementsByClassName('snr-m-' + ls_Target);"
					lk_Out.puts "    for (var k = 0; k < lk_Elements.length; ++k) lk_Elements[k].firstChild.data = ls_SnrMean;"
					lk_Out.puts "    lk_Elements = document.getElementsByClassName('snr-s-' + ls_Target);"
					lk_Out.puts "    for (var k = 0; k < lk_Elements.length; ++k) lk_Elements[k].firstChild.data = ls_SnrStdDev;"
					lk_Out.puts "  }"
					lk_Out.puts "}"
					lk_Out.puts "var gk_Element;"
					lk_Out.puts "var gi_Phase; var gk_Timer;"
					lk_Out.puts "function fade() {"
					lk_Out.puts "gi_Phase++; s = gi_Phase; if (s > 16) s = 32 - s; "
					lk_Out.puts "r = Math.round((255 - (s * 64 / 16))).toString(16); if (r.length < 2) r = \"0\" + r;"
					lk_Out.puts "g = Math.round((255 - (s * 255 / 16))).toString(16); if (g.length < 2) g = \"0\" + g;"
					lk_Out.puts "b = Math.round((255 - (s * 255 / 16))).toString(16); if (b.length < 2) b = \"0\" + b;"
					lk_Out.puts "gk_Element.style.backgroundColor = \"#\" + r + g + b; //alert(r);"
					lk_Out.puts "if (gi_Phase >= 32) clearTimeout(gk_Timer); else gk_Timer = setTimeout(\"fade()\", 20);"
					lk_Out.puts "}"
					lk_Out.puts "function flashPeptide(as_Name) {"
					lk_Out.puts "lk_Element = document.getElementById(as_Name);"
					lk_Out.puts "gk_Element = lk_Element;"
					lk_Out.puts "gi_Phase = 0;"
					lk_Out.puts "gk_Timer = setTimeout(\"fade()\", 20);"
					lk_Out.puts "}"
					
					lk_Out.puts "]]>"
					lk_Out.puts "</script>"
=end					
					lk_Out.puts '</head>'
					lk_Out.puts '<body>'
					lk_Out.puts "<h1>SimQuant Report</h1>"
					lk_Out.puts '<p>'
					lk_Out.puts "Trying charge states #{@param[:minCharge]} to #{@param[:maxCharge]} and merging the upper #{@param[:cropUpper]}% (SNR) of all scans in which a peptide was found.<br />"
					lk_Out.puts "Quantitation has been attempted in #{@param[:scanType] == 'sim' ? 'SIM scans only' : 'all MS1 scans'}, considering #{@param[:isotopeCount]} isotope peaks for both the unlabeled and the labeled ions.<br />"
					lk_Out.puts '</p>'
					
					lk_Out.puts '<h2>Contents</h2>'
					lk_Out.puts '<ol>'
					lk_Out.puts "<li><a href='#header-quantified-proteins'>Quantified proteins</a></li>"
					lk_Out.puts "<li><a href='#header-quantified-peptides'>Quantified peptides</a></li>"
					lk_Out.puts "</ol>"
					
					lk_Out.puts "<h2 id='header-quantified-proteins'>Quantified proteins</h2>"
					
					lk_Out.puts "<table>"
					lk_Out.puts "<tr><th rowspan='2'>Spot / Protein / Peptides</th><th colspan='2'>Ratio</th><th colspan='2'>SNR</th></tr>"
					lk_Out.puts "<tr><th>mean</th><th>std. dev.</th><th>mean</th><th>std. dev.</th></tr>"
					
					lk_Results['results'].keys.sort { |a, b| String::natcmp(a, b) }.each do |ls_Spot|
						lk_Out.puts "<tr><td style='border: none' colspan='6'></td></tr>"
						lk_Out.puts "<tr style='background-color: #ddd;'>"
						lk_Out.puts "<td colspan='5'><b>#{ls_Spot}</b></td>"
						lk_Out.puts "</tr>"
						
						lk_Results['results'][ls_Spot]['proteins'].keys.sort { |a, b| String::natcmp(a, b) }.each do |ls_Protein|
							lk_Out.puts "<tr><td style='border: none' colspan='6'></td></tr>"
							lk_Out.puts "<tr style='background-color: #eee;'>"
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
					
					lk_Out.puts "</table>"
					
					lk_Out.puts "<h2 id='header-quantified-peptides'>Quantified peptides</h2>"
					
					lk_Out.puts "<table style='min-width: 820px;'>"
					lk_Out.puts "<tr><th rowspan='2'>Spot / Peptide / Scan</th><th colspan='2'>Ratio</th><th colspan='2'>SNR</th><th rowspan='2'>manual exclusion</th></tr>"
					lk_Out.puts "<tr><th>mean</th><th>std. dev.</th><th>mean</th><th>std. dev.</th></tr>"
					lk_Results['results'].keys.sort { |a, b| String::natcmp(a, b) }.each do |ls_Spot|
						lk_Out.puts "<tr><td style='border: none' colspan='6'></td></tr>"
						lk_Out.puts "<tr style='background-color: #ddd;'>"
						lk_Out.puts "<td colspan='6'><b>#{ls_Spot}</b></td>"
						lk_Out.puts "</tr>"
						
						lk_Results['results'][ls_Spot]['peptides'].keys.sort { |a, b| String::natcmp(a, b) }.each do |ls_Peptide|
							lk_Out.puts "<tr><td style='border: none' colspan='6'></td></tr>"
							lk_Out.puts "<tr style='background-color: #eee;'><td><b>#{ls_Peptide}</b></td>"
							lk_Out.puts "<td style='text-align: right;'>#{cutMax(0.0)}</td>"
							lk_Out.puts "<td style='text-align: right;'>#{cutMax(0.0)}</td>"
							lk_Out.puts "<td style='text-align: right;'>#{cutMax(0.0)}</td>"
							lk_Out.puts "<td style='text-align: right;'>#{cutMax(0.0)}</td>"
							lk_Out.puts "<td></td>"
							lk_Out.puts "</tr>"
							
							lk_Scans = lk_Results['results'][ls_Spot]['peptides'][ls_Peptide]['scanResults']
							lk_Scans.sort! { |a, b| a['retentionTime'] <=> b['retentionTime'] }
							lk_Scans.each do |lk_Scan|
								lk_Out.puts "<tr><td style='border: none' colspan='6'></td></tr>"
								lk_Out.puts "<tr><td>scan ##{lk_Scan['id']} (charge #{lk_Scan['charge']}+)</td>"
								lk_Out.puts "<td style='text-align: right;'>#{cutMax(lk_Scan['ratio'])}</td>"
								lk_Out.puts "<td style='border-left: none;'></td>"
								lk_Out.puts "<td style='text-align: right;'>#{cutMax(lk_Scan['snr'])}</td>"
								lk_Out.puts "<td style='border-left: none;'></td>"
								lk_Out.puts "<td style='background-color: #b1d28f;' class='clickableCell'>included</td>"
								
								lk_Out.puts "</tr>"
								
								ls_Svg = File::read(File::join(ls_SvgPath, lk_Scan['svg'] + '.svg'))
								ls_Svg.sub!(/<\?xml.+\?>/, '')
								ls_Svg.sub!(/<svg width=\".+\" height=\".+\"/, "<svg ")
								lk_Out.puts "<tr><td colspan='6'>"
								lk_Out.puts "<div>#{ls_Spot} ##{lk_Scan['id']} @ #{sprintf("%1.2f", lk_Scan['retentionTime'].to_f)} minutes: charge: #{lk_Scan['charge']}+ / #{lk_Scan['filterLine']}</div>"
								lk_Out.puts ls_Svg
								lk_Out.puts "</td></tr>"
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
