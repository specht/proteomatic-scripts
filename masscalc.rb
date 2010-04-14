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
require 'yaml'
require 'set'


class MassCalc < ProteomaticScript
	def run()
		lk_Masses = {'G' => 57.021464, 'A' => 71.037114, 'S' => 87.032029,
			'P' => 97.052764, 'V' => 99.068414, 'T' => 101.04768, 'C' => 103.00919,
			'L' => 113.08406, 'I' => 113.08406, 'N' => 114.04293, 'D' => 115.02694,
			'Q' => 128.05858, 'K' => 128.09496, 'E' => 129.04259, 'M' => 131.04048,
			'H' => 137.05891, 'F' => 147.06841, 'R' => 156.10111, 'Y' => 163.06333,
			'W' => 186.07931, '$' => 0.0, 'X' => 0.0}
		ld_Water = 18.01057
		# UNSURE ABOUT THIS VALUE BUT OK WITH BIANCAS EXAMPLES, should be 1.0078250
		ld_Hydrogen = 1.0073250
		
		lk_PeptideHash = Hash.new
		lk_PeptideSet = Set.new
		@input[:peptides].each do |ls_Path|
			ls_File = File::read(ls_Path)
			ls_File.each_line do |ls_Line|
				ls_Peptide = ls_Line.strip
				next if ls_Peptide.empty?
				if (ls_Peptide.include?('.'))
					lk_Peptide == ls_Peptide.split('.')
					ls_Peptide = lk_Peptide[1] if (lk_Peptide.size == 3)
				end
				lk_PeptideSet.add(ls_Peptide)
			end
		end
		lk_Peptides = lk_PeptideSet.to_a.sort
		lk_Peptides.each do |ls_Peptide|
			ld_Mass = ld_Water
			(0...ls_Peptide.size).each do |i|
				ls_AminoAcid = ls_Peptide[i, 1]
				ld_Mass += lk_Masses[ls_AminoAcid]
			end
			lk_PeptideHash[ls_Peptide] = Hash.new
			(1..3).each do |li_Charge|
				ld_Mz = (ld_Mass + ld_Hydrogen * li_Charge) / li_Charge
				lk_PeptideHash[ls_Peptide][li_Charge.to_s] = sprintf('%1.5f', ld_Mz)
			end
			lk_FragmentMasses = Array.new
			ld_Mass = ld_Water
			(0...ls_Peptide.size - 1).each do |i|
				ls_AminoAcid = ls_Peptide[-1 - i, 1]
				ld_Mass += lk_Masses[ls_AminoAcid]
				ld_Mz = ld_Mass + ld_Hydrogen
				lk_FragmentMasses.push(sprintf("%1.5f", ld_Mz))
			end
			lk_PeptideHash[ls_Peptide]['yions'] = lk_FragmentMasses.join(', ')
		end
		
		if @output[:peptideMasses]
			File.open(@output[:peptideMasses], 'w') do |lk_Out|
				lk_Out.puts '<html>'
				lk_Out.puts '<head>'
				lk_Out.puts '<title>Peptide Masses</title>'
				lk_Out.puts '<style type=\'text/css\'>'
				lk_Out.puts 'body {font-family: Verdana; font-size: 10pt;}'
				lk_Out.puts 'h1 {font-size: 14pt;}'
				lk_Out.puts 'h2 {font-size: 12pt; border-top: 1px solid #888; border-bottom: 1px solid #888; padding-top: 0.2em; padding-bottom: 0.2em; background-color: #e8e8e8; }'
				lk_Out.puts 'h3 {font-size: 10pt; }'
				lk_Out.puts 'h4 {font-size: 10pt; font-weight: normal;}'
				lk_Out.puts '.default { }'
				lk_Out.puts '.nonDefault { background-color: #ada;}'
				lk_Out.puts 'table {border-collapse: collapse;} '
				lk_Out.puts 'table tr {text-align: left; font-size: 10pt;}'
				lk_Out.puts 'table th, td {vertical-align: top; border: 1px solid #888; padding: 0.2em;}'
				lk_Out.puts 'table th {font-weight: bold;}'
				lk_Out.puts '</style>'
				lk_Out.puts '</head>'
				lk_Out.puts '<body>'
				lk_Out.puts '<h1>Peptide masses</h1>'
				lk_Out.puts "<table>"
                lk_Out.puts "<thead>"
				lk_Out.puts "<tr><th>Peptide</th><th>MH<sup>+2</sup> (mono)</th><th>MH<sup>+3</sup> (mono)</th><th>Y fragment ions</th></tr>"
                lk_Out.puts "</thead>"
                lk_Out.puts "<tbody>"
				lk_Peptides.each do |ls_Peptide|
					lk_Out.puts "<tr>"
					lk_Out.puts "<td>#{ls_Peptide}</td>"
					(2..3).each do |li_Charge|
						lk_Out.printf "<td>#{lk_PeptideHash[ls_Peptide][li_Charge.to_s]}</td>"
					end
					lk_Out.print "<td>#{lk_PeptideHash[ls_Peptide]['yions']}</td>"
					lk_Out.puts "</tr>"
				end
                lk_Out.puts "</tbody>"
				lk_Out.puts '</table></body></html>'
			end
		end
		if @output[:msPeptideMasses]
			File.open(@output[:msPeptideMasses], 'w') do |lk_Out|
				lk_Peptides.each do |ls_Peptide|
					lk_Out.puts(lk_PeptideHash[ls_Peptide]['2'])
					lk_Out.puts(lk_PeptideHash[ls_Peptide]['3'])
				end
			end
		end
	end
end

lk_Object = MassCalc.new
