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
require 'include/ext/fastercsv'
require 'include/misc'
require 'set'
require 'yaml'

class ExportPsmToAms < ProteomaticScript
	def run()
		@output.each do |ls_InPath, ls_OutPath|
			lk_Result = loadPsm(ls_InPath)
			
			lk_ScanHash = lk_Result[:scanHash]
			lk_PeptideHash = lk_Result[:peptideHash]
			lk_GpfPeptides = lk_Result[:gpfPeptides]
			lk_ModelPeptides = lk_Result[:modelPeptides]
			lk_ProteinIdentifyingModelPeptides = lk_Result[:proteinIdentifyingModelPeptides]
			lk_Proteins = lk_Result[:proteins]
			lk_ScoreThresholds = lk_Result[:scoreThresholds]
			lk_ActualFpr = lk_Result[:actualFpr]
			lk_SpectralCounts = lk_Result[:spectralCounts]
			File.open(ls_OutPath, 'w') do |lk_Out|
				lk_NeededSpots = Set.new
				lk_NeededScans = Set.new
				lk_FoundToSoftware = {:models => 'OMSSA', :gpf => 'GPF-OMSSA'}
				lk_SpotToSpectraFile = Hash.new
				@input[:spectra].each { |ls_Path| lk_SpotToSpectraFile[File::basename(ls_Path).split('.').first] = ls_Path } if @input[:spectra]
				
				# see which scans have to be read from the spectrum files
				lk_PeptideHash.each do |ls_Peptide, lk_Peptide|
					lk_Peptide[:scans].each do |ls_Scan|
						lk_NeededScans.add(ls_Scan)
						ls_Spot = ls_Scan.split('.').first
						lk_NeededSpots.add(ls_Spot)
					end
				end
				
				lk_MissingSpots = Array.new
				lk_NeededSpots.each { |ls_Spot|	lk_MissingSpots.push(ls_Spot) unless lk_SpotToSpectraFile[ls_Spot] }
				lk_ScanData = Hash.new
				lk_MeasuredMasses = Hash.new
				
				unless lk_MissingSpots.empty?
					puts "ATTENTION: The measures masses and spectral data for the following spots can not be included into the 2DB upload file because the following spots have not been specified as input files: #{lk_MissingSpots.join(', ')}."
				end

=begin
				#fetch measured masses and spectral data
				print 'Extracting spectral data...' unless lk_NeededSpots.to_a == lk_MissingSpots
				lk_NeededSpots.each do |ls_Spot|
					ls_Filename = lk_SpotToSpectraFile[ls_Spot]
					next unless ls_Filename
					
					lk_SpectrumProc = Proc.new do |ls_Filename, ls_Contents|
						if (lk_NeededScans.include?(ls_Filename))
							ls_Contents.gsub!("\n", ';')
							ls_Contents.gsub!(' ', ',')
							lk_ScanData[ls_Filename] = ls_Contents 
						end
						lk_MeasuredMasses[ls_Filename] = ls_Contents.split("\n").first.split(' ').first.to_f - 1.007825
					end
					
					DtaIterator.new(ls_Filename, lk_SpectrumProc).run
				end
				puts 'done.' unless lk_NeededSpots.to_a == lk_MissingSpots
=end
				
				# write AMS header
				lk_Out.puts "spectrum_id!software!charge!meas_mass!cal_mass!delta_mass!scores!sequence_in!sequence_out!left_fragment!right_fragment!left_pos!right_pos!left_rf!right_rf!tic!database!reference!spectrum!search_string!"
				
				# iterate OMSSA results
				lk_PeptideHash.each do |ls_Peptide, lk_Peptide|
					lk_Peptide[:scans].each do |ls_Scan|
						lk_Peptide[:found].keys.each do |ls_Found|
							ls_Software = lk_FoundToSoftware[ls_Found]
							lk_ScanNameParts = ls_Scan.split('.')
							li_Charge = lk_ScanNameParts[3].to_i
							ls_Spot = lk_ScanNameParts.first
							ls_SpotFilename = lk_SpotToSpectraFile[ls_Spot]
							lf_CalculatedMass = lk_ScanHash[ls_Scan][:peptides][ls_Peptide][:calculatedMass].to_f
							lf_MeasuredMass = lk_ScanHash[ls_Scan][:peptides][ls_Peptide][:measuredMass].to_f
							lf_MeasuredMass = lf_CalculatedMass unless lf_MeasuredMass
							lf_EValue = lk_ScanHash[ls_Scan][:e]
							ls_SpectrumData = lk_ScanData[ls_Scan]
							ls_SpectrumData = '' unless ls_SpectrumData
							# database and reference intentionally left blank because 2DB does
							# the search by itself.
							ls_Database = ''
							ls_Reference = ''
							ls_Fpr = ''
							ls_Fpr = ",fpr:#{lk_ActualFpr[ls_Spot]}" if lk_ActualFpr[ls_Spot]
							# add trailing .dta if it's not there
							ls_Scan += '.dta' unless ls_Scan[-4, 4].downcase == '.dta'
							lk_Out.puts "#{ls_Scan}!#{ls_Software}!#{li_Charge}!#{lf_MeasuredMass}!#{lf_CalculatedMass}!#{lf_MeasuredMass - lf_CalculatedMass}!evalue:#{lf_EValue}#{ls_Fpr}!!#{ls_Peptide}!!!!!!!!#{ls_Database}!#{ls_Reference}!#{ls_SpectrumData}!!"
						end
					end
				end
			end
		end
	end
end

lk_Object = ExportPsmToAms.new
