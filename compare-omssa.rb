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

require 'include/ruby/proteomatic'
require 'include/ruby/evaluate-omssa-helper'
require 'include/ruby/ext/fastercsv'
require 'include/ruby/misc'
require 'set'
require 'yaml'

class CompareOmssa < ProteomaticScript
	def run()
		lk_RunResults = Hash.new
		# compare multiple OMSSA results
		@input[:psmFile].each do |ls_Path|
			ls_Key = File::basename(ls_Path)
			ls_Key.sub!('psm-cropped.csv', '')
			ls_Key = ls_Key[0, ls_Key.size - 1] while ((!ls_Key.empty?) && ('_-. '.include?(ls_Key[ls_Key.size - 1, 1])))
			lk_RunResults[ls_Key] = loadPsm(ls_Path)
		end
		
		lk_RunKeys = lk_RunResults.keys.sort { |x, y| String::natcmp(x, y) }
		
		# collect proteins from all runs
		lk_AllProteinsSet = Set.new
		if (@param[:useSafeProteins])
			lk_RunKeys.each { |ls_Key| lk_AllProteinsSet.merge(lk_RunResults[ls_Key][:safeProteins].to_a) }
		else
			lk_RunKeys.each { |ls_Key| lk_AllProteinsSet.merge(lk_RunResults[ls_Key][:proteins].keys) }
		end
		lk_Proteins = lk_AllProteinsSet.to_a.sort { |x, y| String::natcmp(x, y) }
		
		if @output[:htmlReport]
			File.open(@output[:htmlReport], 'w') do |lk_Out|
				
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
				lk_Out.puts "<tr><th rowspan='2'>Protein</th><th colspan='#{lk_RunKeys.size}'>Spectra count</th><th rowspan='2'>std. dev.</th><th colspan='#{lk_RunKeys.size}'>Distinct peptide count</th><th rowspan='2'>std. dev.</th></tr>"
				lk_Out.puts "<tr>#{lk_RunKeys.collect { |x| '<th>' + x + '</th>'}.join('') }#{lk_RunKeys.collect { |x| '<th>' + x + '</th>'}.join('') }</tr>"
				lk_Proteins.each do |ls_Protein|
					lk_Out.print "<tr><td>#{ls_Protein}</td>"
					
					lk_Values = Array.new
					ls_SpectralCountString = lk_RunKeys.collect do |ls_Key|
						li_Count = 0
						li_Count = lk_RunResults[ls_Key][:spectralCounts][:proteins][ls_Protein][:total] if lk_RunResults[ls_Key][:proteins].has_key?(ls_Protein)
						lk_Values.push(li_Count)
						"<td>#{li_Count}</td>"
					end.join('')
					lk_Out.print ls_SpectralCountString
					lk_Out.print "<td>#{sprintf("%1.2f", stddev(lk_Values))}</td>"
					
					lk_Values = Array.new
					ls_DistinctPeptidesCountString = lk_RunKeys.collect do |ls_Key|
						li_Count = 0
						li_Count = lk_RunResults[ls_Key][:proteins][ls_Protein].size if lk_RunResults[ls_Key][:proteins].has_key?(ls_Protein)
						lk_Values.push(li_Count)
						"<td>#{li_Count}</td>"
					end.join('')
					lk_Out.print ls_DistinctPeptidesCountString
					lk_Out.print "<td>#{sprintf("%1.2f", stddev(lk_Values))}</td>"
					
					lk_Out.print "</tr>"
					lk_Out.puts
				end
				lk_Out.puts '</table>'
				
				
				lk_Out.puts '</body>'
				lk_Out.puts '</html>'
			end
		end
		
		if @output[:csvReport]
			File.open(@output[:csvReport], 'w') do |lk_Out|
				ls_PlaceHolder = ';' * lk_RunKeys.size
				lk_Out.puts "Protein;Spectra count#{ls_PlaceHolder}std. dev.;Distinct peptide count#{ls_PlaceHolder}std. dev."
				lk_Out.puts ";#{lk_RunKeys.join(';') };;#{lk_RunKeys.join(';') };"
				lk_Proteins.each do |ls_Protein|
					lk_Out.print "\"#{ls_Protein}\";"
					
					lk_Values = Array.new
					ls_SpectralCountString = lk_RunKeys.collect do |ls_Key|
						li_Count = 0
						li_Count = lk_RunResults[ls_Key][:spectralCounts][:proteins][ls_Protein][:total] if lk_RunResults[ls_Key][:proteins].has_key?(ls_Protein)
						lk_Values.push(li_Count)
						"#{li_Count};"
					end.join('')
					lk_Out.print ls_SpectralCountString
					lk_Out.print "#{sprintf("%1.2f", stddev(lk_Values))};"
					
					lk_Values = Array.new
					ls_DistinctPeptidesCountString = lk_RunKeys.collect do |ls_Key|
						li_Count = 0
						li_Count = lk_RunResults[ls_Key][:proteins][ls_Protein].size if lk_RunResults[ls_Key][:proteins].has_key?(ls_Protein)
						lk_Values.push(li_Count)
						"#{li_Count};"
					end.join('')
					lk_Out.print ls_DistinctPeptidesCountString
					lk_Out.print "#{sprintf("%1.2f", stddev(lk_Values))}"
					lk_Out.puts
				end
			end
		end
	end
end

lk_Object = CompareOmssa.new
