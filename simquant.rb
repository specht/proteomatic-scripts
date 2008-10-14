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
	def cutMax(af_Value, ai_Max, ai_Places = 2)
		return af_Value > ai_Max.to_f ? "> #{ai_Max}" : sprintf("%1.#{ai_Places}f", af_Value)
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
		ls_YamlPath = File::join(ls_TempPath, 'out.yaml')
		ls_SvgPath = File::join(ls_TempPath, 'svg')
		FileUtils::mkpath(ls_TempPath)
		FileUtils::mkpath(ls_SvgPath)
		
		ls_Command = "\"#{ExternalTools::binaryPath('simquant.simquant')}\" --scanType #{@param[:scanType]} --isotopeCount #{@param[:isotopeCount]} --cropUpper #{@param[:cropUpper] / 100.0} --minSnr #{@param[:minSnr]} --maxOffCenter #{@param[:maxOffCenter] / 100.0} --maxTimeDifference #{@param[:maxTimeDifference]} --textOutput no --yamlOutput yes --yamlOutputTarget \"#{ls_YamlPath}\" --svgOutPath \"#{ls_SvgPath}\" --files #{@input[:spectra].collect {|x| '"' + x + '"'}.join(' ')} --peptides #{lk_Peptides.join(' ')} --peptideFiles #{@input[:peptideFiles].collect {|x| '"' + x + '"'}.join(' ')}"
		runCommand(ls_Command, true)
		
		lk_Results = YAML::load_file(ls_YamlPath)
		
		if ((!lk_Results.include?('results')) || (lk_Results['results'].class != Hash))
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
					lk_Out.puts '.toggle { text-decoration: underline; color: #aaa; }'
					lk_Out.puts '.toggle:hover { cursor: pointer; color: #000; }'
					lk_Out.puts '</style>'
					lk_Out.puts "<script type='text/javascript'>"
					lk_Out.puts "<![CDATA["
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
					lk_Out.puts "]]>"
					lk_Out.puts "</script>"
					lk_Out.puts '</head>'
					lk_Out.puts '<body>'
					lk_Out.puts "<h1>SimQuant Report</h1>"
					lk_Out.puts '<p>'
					lk_FoundPeptides = Array.new
					lk_FoundPeptides = lk_Results['results'].keys if lk_Results['results']
					lk_NotFoundPeptides = lk_Peptides.reject { |x| lk_FoundPeptides.include?(x) }
					lk_Out.puts "Quantified #{lk_FoundPeptides.size} peptides in #{@input[:spectra].size} file#{@input[:spectra].size != 1 ? 's' : ''}, trying charge states #{@param[:minCharge]} to #{@param[:maxCharge]} and merging the upper #{@param[:cropUpper]}% (SNR) of all scans in which a peptide was found.<br />"
					lk_Out.puts "Quantitation has been attempted in #{@param[:scanType] == 'sim' ? 'SIM' : 'all'} scans, considering #{@param[:isotopeCount]} isotope peaks for both the unlabeled and the labeled ions.<br />"
					lk_Out.puts '</p>'
					
					lk_Proteins = Hash.new
					lk_Results['results'].keys.each do |ls_Peptide|
						ls_Protein = ''
						ls_Protein = lk_Results['results'][ls_Peptide]['protein'] if lk_Results['results'][ls_Peptide]['protein']
						ls_Protein = '(no protein specified)' if ls_Protein.empty?
						lk_Proteins[ls_Protein] ||= Array.new
						lk_Proteins[ls_Protein].push(ls_Peptide)
					end
					
					lk_Peptides = lk_Results['results'].keys.sort
					
					lk_Out.puts "<h2>Quantified proteins</h2>"
					
					lk_Out.puts "<span class='toggle' onclick=\"show('scans-all');\">[show all spectra]</span> "
					lk_Out.puts "<span class='toggle' onclick=\"hide('scans-all');\">[hide all spectra]</span> <br />"
	
					lk_Out.puts "<table style='min-width: 820px;'>"
					li_StaticToggleCounter = 0
					lk_ProteinKeys = lk_Proteins.keys.sort { |a, b| String::natcmp(a, b) }
					
					lk_ProteinKeys.each do |ls_Protein|
						lk_Peptides = lk_Proteins[ls_Protein].sort
						lk_Out.puts "<tr><td colspan='4' style='border: none; padding-top: 1em;'><b>#{ls_Protein}</b></td></tr>"
						lk_Peptides.each do |ls_Peptide|
							lk_Out.puts "<tr><td colspan='4' style='border: none; padding-top: 1em; padding-bottom: 1em;'>#{ls_Peptide}</td></tr>"
							lk_Out.puts "<tr><th>Spot</th><th>Ratio mean (std. dev.)</th><th>SNR mean (std. dev.)</th><th>Scans</th></tr>"
							lk_PeptideResults = lk_Results['results'][ls_Peptide]['results']
							lk_PeptideResults.sort! { |a, b| String::natcmp(a['file'], b['file']) }
							lk_PeptideResults.each do |lk_Row|
								lk_SubRows = lk_Row['scans']
								lk_SubRows.sort! { |a, b| a['retentionTime'] <=> b['retentionTime'] }
								ls_Name = "scan-#{li_StaticToggleCounter}"
								li_StaticToggleCounter += 1
								lk_Out.puts "<tr><td>#{lk_Row['file']}</td><td>#{sprintf("%1.2f (%1.2f)", lk_Row['ratioMean'].to_f, lk_Row['ratioStandardDeviation'].to_f)}</td><td>#{cutMax(lk_Row['snrMean'].to_f, 10000, 2)} (#{cutMax(lk_Row['snrStandardDeviation'].to_f, 10000, 2)})</td><td><span class='toggle' onclick=\"toggle('#{ls_Name}')\">#{lk_SubRows.size} scans</span></td></tr>"
								lk_SubRows.each do |lk_SubRow|
									ls_Svg = File::read(File::join(ls_SvgPath, lk_SubRow['svg'] + '.svg'))
									ls_Svg.sub!(/<\?xml.+\?>/, '')
									ls_Svg.sub!(/<svg width=\".+\" height=\".+\"/, "<svg ")
									lk_Out.puts "<tr class='sub #{ls_Name} scans-all' style='display: none;'><td>#{lk_Row['file']}</td><td>#{sprintf("%1.2f", lk_SubRow['ratio'].to_f)}</td><td>#{cutMax(lk_SubRow['snr'].to_f, 10000, 2)}</td><td></td></tr>"
									lk_Out.puts "<tr class='sub #{ls_Name} scans-all' style='display: none;'><td colspan='4'>"
									lk_Out.puts "<div>#{lk_Row['file']} ##{lk_SubRow['id']} @ #{sprintf("%1.2f", lk_SubRow['retentionTime'].to_f)} minutes: charge: #{lk_SubRow['charge']}+ / #{lk_SubRow['filterLine']}</div>"
									lk_Out.puts ls_Svg
									lk_Out.puts "</td></tr>"
								end
							end
						end
					end
					lk_Out.puts '</table>'
					lk_Out.puts '</body>'
					lk_Out.puts '</html>'
				end
			end
		end
	end
end

lk_Object = SimQuant.new
