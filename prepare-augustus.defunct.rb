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
require 'include/fastercsv'
require 'include/misc'
require 'set'
require 'yaml'


class PrepareAugustus < ProteomaticScript
	def run()
		lk_CsvFiles = @input[:omssaResults]
		
		lk_ScanHash = Hash.new
		#MT_HydACPAN_25_020507.1058.1058.2.dta:
		#  e: 3.88761e-07
		#  peptides:
		#    NLLAALNHEETR: true
		#  deflines:
		#  - target_proteins.finalModelsV2.fasta;171789
		#  - target_proteins.frozen_GeneCatalog_2007_09_13.fasta;jgi|Chlre3|194475
		#  - target_gpf-peptides.fasta;NLLAALNHEETR
		#  (added later:)
		#  decoy: false
		
		lk_CsvFiles.each do |ls_Filename|
			lk_File = File.open(ls_Filename, 'r')
			lk_File.readline
			
			lk_File.each do |ls_Line|
				lk_Line = ls_Line.parse_csv()
				ls_Scan = lk_Line[1]
				ls_Peptide = lk_Line[2]
				lf_E = lk_Line[3]
				ls_DefLine = lk_Line[9]
				
				lk_ScanHash[ls_Scan] = Hash.new if !lk_ScanHash.has_key?(ls_Scan)
				if (!lk_ScanHash[ls_Scan].has_key?('e') || lf_E < lk_ScanHash[ls_Scan]['e'])
					# clear scan hash
					lk_ScanHash[ls_Scan]['peptides'] = {ls_Peptide => true}
					lk_ScanHash[ls_Scan]['deflines'] = [ls_DefLine]
					lk_ScanHash[ls_Scan]['e'] = lf_E;
				elsif (lf_E == lk_ScanHash[ls_Scan]['e'])
					lk_ScanHash[ls_Scan]['peptides'][ls_Peptide] = true
					lk_ScanHash[ls_Scan]['deflines'].push(ls_DefLine)
				end
			end
		end
		
		lk_ScanHash.keys.each do |ls_Scan|
			lb_Decoy = false
			lk_ScanHash[ls_Scan]['deflines'].each { |ls_DefLine| lb_Decoy = true if ls_DefLine[0, 6] == 'decoy_' }
			lk_ScanHash[ls_Scan]['decoy'] = lb_Decoy
		end
		
		# sort scans by e value
		lk_ScansByE = lk_ScanHash.keys.sort { |a, b| lk_ScanHash[a]['e'] <=> lk_ScanHash[b]['e'] }
		
		li_TotalCount = 0
		li_DecoyCount = 0
		li_CropCount = 0
		lk_ScansByE.each do |ls_Scan|
			li_TotalCount += 1
			li_DecoyCount += 1 if lk_ScanHash[ls_Scan]['decoy']
			lf_Fpr = li_DecoyCount.to_f * 2.0 / li_TotalCount.to_f * 100.0
			li_CropCount = li_TotalCount if lf_Fpr < param('targetFpr')
		end
		
		lk_GoodScans = lk_ScansByE[0, li_CropCount]
		lk_GoodScans.delete_if { |ls_Scan| lk_ScanHash[ls_Scan]['decoy'] || lk_ScanHash[ls_Scan]['peptides'].size > 1 }
		
		puts "Cropped #{lk_GoodScans.size} spectra from #{lk_ScanHash.size}."
		puts "E-value threshold is #{lk_ScanHash[lk_GoodScans.last]['e']} at a maximum fpr of #{param('targetFpr')}%."
		
		lk_PeptideHash = Hash.new
		#WLQYSEVIHAR:
		#  scans: [MT_HydACPAN_1_300407.100.100.2, ...]
		#  spots: (MT_HydACPAN_1_300407) (set)
		#  found: {gpf, models}
		#  proteins: {x => true, y => true}
		
		lk_GoodScans.each do |ls_Scan|
			ls_Peptide = lk_ScanHash[ls_Scan]['peptides'].keys.first
			if !lk_PeptideHash.has_key?(ls_Peptide)
				lk_PeptideHash[ls_Peptide] = Hash.new 
				lk_PeptideHash[ls_Peptide]['scans'] = Array.new
				lk_PeptideHash[ls_Peptide]['spots'] = Set.new
				lk_PeptideHash[ls_Peptide]['found'] = Hash.new
				lk_PeptideHash[ls_Peptide]['proteins'] = Hash.new
			end
			lk_PeptideHash[ls_Peptide]['scans'].push(ls_Scan)
			lk_PeptideHash[ls_Peptide]['spots'].add(ls_Scan[0, ls_Scan.index('.')])
			lk_ScanHash[ls_Scan]['deflines'].each do |ls_DefLine|
				if (ls_DefLine[0, 12] == 'target_gpf__')
					lk_PeptideHash[ls_Peptide]['found']['gpf'] = true 
				else
					lk_PeptideHash[ls_Peptide]['found']['models'] = true 
					lk_PeptideHash[ls_Peptide]['proteins'][ls_DefLine] = true
				end
			end
		end
		
		
		# sort scans in lk_PeptideHash by e-value
		lk_PeptideHash.keys.each do |ls_Peptide|
			lk_PeptideHash[ls_Peptide]['scans'] = lk_PeptideHash[ls_Peptide]['scans'].sort { |a, b| lk_ScanHash[a]['e'] <=> lk_ScanHash[b]['e'] }
		end
		
		puts "Unique peptides identified: #{lk_PeptideHash.size}."
		
		lk_GpfPeptides = Set.new
		lk_ModelPeptides = Set.new
		
		lk_PeptideHash.keys.each do |ls_Peptide|
			lk_GpfPeptides.add(ls_Peptide) if lk_PeptideHash[ls_Peptide]['found'].has_key?('gpf')
			lk_ModelPeptides.add(ls_Peptide) if lk_PeptideHash[ls_Peptide]['found'].has_key?('models')
		end
		
		puts "Peptides found by both GPF and models: #{(lk_GpfPeptides & lk_ModelPeptides).size}."
		puts "Peptides found by GPF alone: #{(lk_GpfPeptides - lk_ModelPeptides).size}."
		puts "Peptides found by models alone: #{(lk_ModelPeptides - lk_GpfPeptides).size}."
		
		# run GPF again, without similarity search
		ls_QueryFile = tempFilename("gpf-queries")
		File::open(ls_QueryFile, 'w') { |lk_File| lk_File.write(lk_PeptideHash.keys.sort.join("\n")) }
		ls_ResultFile = tempFilename("gpf-results");
		ls_Command = "#{ExternalTools::binaryPath('gpf.gpfbatch')} searchSimilar no fullDetails yes #{@param[:genome]} #{ls_QueryFile} #{ls_ResultFile}"
		system(ls_Command)
		gk_GpfResults = YAML::load_file(ls_ResultFile)
		
		lk_PeptideInfo = Hash.new
		lk_PeptideHash.keys.sort.each do |ls_Peptide|
			lk_PeptideInfo[ls_Peptide] = Hash.new
			lk_PeptideInfo[ls_Peptide]['assemblies'] = gk_GpfResults[ls_Peptide]
			lk_PeptideInfo[ls_Peptide]['scans'] = lk_PeptideHash[ls_Peptide]['scans'].to_a.sort
			lk_PeptideInfo[ls_Peptide]['found'] = lk_PeptideHash[ls_Peptide]['found'].keys.sort	
		end
		puts lk_PeptideInfo.to_yaml
	end
end

lk_Object = PrepareAugustus.new
