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

class AugustusCollect < ProteomaticScript
	
	def dumpGpfInfo(ak_GpfInfo, ak_GpfPeptides)
		lk_Result = Hash.new
		lk_ImmediatePeptides = Set.new
		lk_IntronSplitPeptides = Set.new
		lk_TripletSplitPeptides = Set.new
		lk_EvenSplitPeptides = Set.new
		lk_LostPeptides = Set.new
		ak_GpfPeptides.each do |ls_Peptide|
			ls_Key = ls_Peptide
			lk_Info = ak_GpfInfo[ls_Key]
			if (lk_Info == nil)
				lk_LostPeptides.add(ls_Peptide)
				next
			end
			lk_ImmediatePeptides.add(ls_Peptide) if lk_Info[:immediate] > 0
			lk_IntronSplitPeptides.add(ls_Peptide) if lk_Info[:intronSplit] > 0
			lk_TripletSplitPeptides.add(ls_Peptide) if lk_Info[:tripletSplit] > 0
			lk_EvenSplitPeptides.add(ls_Peptide) if lk_Info[:evenSplit] > 0
		end
		lk_Result[:immediateOnly] = (lk_ImmediatePeptides - lk_IntronSplitPeptides).size
		lk_Result[:immediateAndIntronSplit] = (lk_ImmediatePeptides & lk_IntronSplitPeptides).size
		lk_Result[:intronSplit] = (lk_IntronSplitPeptides - lk_ImmediatePeptides - (lk_TripletSplitPeptides - lk_EvenSplitPeptides)).size
		lk_Result[:intronTripletSplitOnly] = (lk_TripletSplitPeptides - lk_EvenSplitPeptides).to_a
		lk_Result[:lost] = lk_LostPeptides.size
		return lk_Result
	end
	
	def run()
		lk_AllPeptides = Set.new
		lk_AllGpfPeptides = Set.new
		lk_AllModelPeptides = Set.new
		lk_AllPeptideOccurences = Hash.new
		@input[:psmFiles].each do |ls_Path|
			#next unless ls_Path.index("Kurs")
			puts ls_Path
			# merge OMSSA results
			lk_Result = loadPsm(ls_Path)
			
			lk_ScanHash = lk_Result[:scanHash]
			lk_PeptideHash = lk_Result[:peptideHash]
			lk_GpfPeptides = lk_Result[:gpfPeptides]
			lk_ModelPeptides = lk_Result[:modelPeptides]
			lk_ProteinIdentifyingModelPeptides = lk_Result[:proteinIdentifyingModelPeptides]
			lk_Proteins = lk_Result[:proteins]
			lk_ScoreThresholds = lk_Result[:scoreThresholds]
			lk_ActualFpr = lk_Result[:actualFpr]
			lk_SpectralCounts = lk_Result[:spectralCounts]
			
			lk_PeptideHash.keys.each do |ls_Peptide|
				lk_AllPeptideOccurences[ls_Peptide] ||= Set.new
				lk_AllPeptideOccurences[ls_Peptide] += Set.new(lk_PeptideHash[lk_PeptideHash.keys.first][:scans])
			end
			
			lk_ProteinsBySpectralCount = lk_Proteins.keys.sort { |a, b| lk_SpectralCounts[:proteins][b][:total] <=> lk_SpectralCounts[:proteins][a][:total]}
			lk_AmbiguousPeptides = (lk_ModelPeptides - lk_ProteinIdentifyingModelPeptides).to_a.sort! do |x, y|
				lk_PeptideHash[x][:scans].size == lk_PeptideHash[y][:scans].size ? x <=> y : lk_PeptideHash[y][:scans].size <=> lk_PeptideHash[x][:scans].size
			end
			
			lk_AllGpfPeptides += lk_GpfPeptides
			lk_AllModelPeptides += lk_ModelPeptides
			lk_AllPeptides += Set.new(lk_PeptideHash.keys)
		end
		lk_Info = Hash.new
		lk_Info[:peptides] = Hash.new
		lk_Info[:peptides][:models] = lk_AllModelPeptides.to_a.sort
		lk_Info[:peptides][:gpf] = lk_AllGpfPeptides.to_a.sort
		lk_Info[:peptideOccurences] = lk_AllPeptideOccurences
		
		#puts lk_Info.to_yaml
		lk_AllPeptides = Set.new(lk_Info[:peptides][:models]) | Set.new(lk_Info[:peptides][:models])
		puts "got #{lk_AllPeptides.size} peptides."
		
		gpfPeptides = Set.new

		File.open('/home/michael/ak-hippler-alignments/gpf-results.yaml') do |file|
			file.each_line do |line|
				next unless line.index('"') == 0
				line.strip!
				line.gsub!('peptide=', '')
				line.gsub!('"', '')
				line.gsub!(':', '')
				gpfPeptides.add(line)
			end
		end
		
		puts "got #{(lk_AllPeptides - gpfPeptides).size} new peptides."
		puts "#{(lk_AllPeptides - gpfPeptides).collect { |x| '>' + x + "\n" + x + "\n" }.join('')}"
		
# 		lk_GpfOnlyPeptides = lk_AllGpfPeptides - lk_AllModelPeptides
# 		puts "got #{lk_GpfOnlyPeptides.size} GPF only peptides."
# 		lk_GpfOnlyPeptides.to_a.sort.each { |x| puts ">gpf__#{x}\n#{x}" }

=begin		
		lk_PeptideSet = Set.new
		File::open('/home/michael/ak-hippler-alignments/collected-gpf-alignments-keys.txt', 'r') do |lk_File|
			lk_PeptideSet += Set.new(lk_File.read().split("\n").reject { |x| x.empty? })
		end
		(lk_AllPeptides - lk_PeptideSet).to_a.sort.each do |ls_Peptide|
			puts ">#{ls_Peptide}\n#{ls_Peptide}\n"
		end
=end		

=begin		
		lk_PeptideSet.to_a.each do |ls_Peptide|
			if !lk_AllPeptides.include?(ls_Peptide)
				puts ls_Peptide
			end
		end
=end

	end
end

lk_Object = AugustusCollect.new
