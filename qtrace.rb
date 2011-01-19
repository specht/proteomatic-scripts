#! /usr/bin/env ruby
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

require './include/ruby/proteomatic'
require './include/ruby/evaluate-omssa-helper'
require './include/ruby/externaltools'
require './include/ruby/fasta'
require './include/ruby/formats'
require './include/ruby/misc'
require 'bigdecimal'
require 'fileutils'
require 'yaml'


class QTrace < ProteomaticScript
    def run()
        # peptides for each spot
        lk_Peptides = Hash.new
        
        # get peptides from PSM list
        @input[:psmFile].each do |ls_Path|
            lk_Result = loadPsm(ls_Path, :silent => true) 
            
            lk_PeptideHash = lk_Result[:peptideHash]
            lk_PeptideHash.each_pair do |ls_Peptide, lk_Hash|
                lk_Hash[:spots].each do |ls_Spot|
                    lk_Peptides[ls_Spot] ||= Set.new
                    lk_Peptides[ls_Spot] << ls_Peptide
                end
            end
        end
        
        # get peptides from parameters
        lk_PeptidesForAll = Array.new
        lk_PeptidesForAll += @param[:peptides].split(%r{[,;\s/]+})
        
        # get peptides from peptides files
        @input[:peptideFiles].each do |ls_Path|
            lk_PeptidesForAll += File::read(ls_Path).split("\n")
        end
        
        lk_PeptidesForAll.collect! { |x| x.upcase.strip }
        
        # convert SEQUEST-type peptides X.PEPTIDEK.X to PEPTIDEK
        lk_PeptidesForAll.collect! do |ls_Peptide|
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

        lk_PeptidesForAll.uniq!
        
        lk_PeptidesForAll.reject! do |ls_Peptide|
            # reject peptide if it's empty
            ls_Peptide.empty?
        end
        lk_Peptides.each_key do |ls_Spot|
            lk_Peptides[ls_Spot].reject! do |ls_Peptide|
                ls_Peptide.empty?
            end
        end

        # if search all in all is turned on, move all spot-dependent peptides
        # to the global search list
        if @param[:searchAllInAll]
            lk_Peptides.each_key do |ls_Spot|
                lk_Peptides[ls_Spot].reject! do |ls_Peptide|
                    lk_PeptidesForAll << ls_Peptide
                end
            end
            lk_Peptides = Hash.new
            lk_PeptidesForAll.uniq!
        end

        # handle amino acid exclusion list
        ls_ExcludeListTemplate = 'ARNDCEQGHILKMFPSTWYV'
        ls_ExcludeList = ''
        (0...ls_ExcludeListTemplate.size).each do |i|
             ls_ExcludeList += ls_ExcludeListTemplate[i, 1] if (@param[:excludeAminoAcids].upcase.include?(ls_ExcludeListTemplate[i, 1]))
        end
        # ls_ExcludeList now contains all amino acids that should be chucked out
        (0...ls_ExcludeList.size).each do |i|
            lk_PeptidesForAll.reject! { |ls_Peptide| ls_Peptide.include?(ls_ExcludeList[i, 1]) }
            lk_Peptides.each_key do |ls_Spot|
                lk_Peptides[ls_Spot].reject! { |ls_Peptide| ls_Peptide.include?(ls_ExcludeList[i, 1]) }
            end
        end
        
        ls_TempPath = tempFilename('qtrace')
        FileUtils::mkpath(ls_TempPath)

        # create csv out file
        if @output[:qtraceCsv]
            File.open(@output[:qtraceCsv], 'w') do |lk_Out|
            end
        end
        
        # create XHTML out file
        if @output[:xhtmlReport]
            File.open(@output[:xhtmlReport], 'w') do |lk_Out|
            end
        end
        
        lb_FirstRun = true
        lb_NeedXhtmlHeader = true
        xhtmlFooter = ''
        @input[:spectraFiles].each do |ls_SpectraFile|
            lb_LastRun = (ls_SpectraFile == @input[:spectraFiles].last)
            ls_Spot = File::basename(ls_SpectraFile).split('.').first
            ls_CsvPath = File::join(ls_TempPath, ls_Spot + '-out.csv')
            ls_XhtmlPath = File::join(ls_TempPath, ls_Spot + '-out.xhtml')
            ls_PeptidesPath = File::join(ls_TempPath, ls_Spot + '-peptides.txt')

            lb_FoundNoPeptides = false
            
            # write all target peptides into one file
            File::open(ls_PeptidesPath, 'w') do |lk_Out|
                lk_ThisPeptides = Set.new
                lk_ThisPeptides += lk_Peptides[ls_Spot] if lk_Peptides[ls_Spot]
                lk_ThisPeptides += Set.new(lk_PeptidesForAll) if lk_PeptidesForAll
                lb_FoundNoPeptides = lk_ThisPeptides.empty?
                lk_Out.puts(lk_ThisPeptides.to_a.sort.join("\n"))
            end

            next if lb_FoundNoPeptides

            csvOutputOptions = '--csvOutput no '
            csvOutputOptions = "--csvOutput yes --csvOutputPath \"#{ls_CsvPath}\" " if @output[:qtraceCsv]
            
            xhtmlOutputOptions = ' '
            xhtmlOutputOptions = "--xhtmlOutputPath \"#{ls_XhtmlPath}\" " if @output[:xhtmlReport]
            
            ls_Command = "\"#{ExternalTools::binaryPath('qtrace.qtrace')}\" --label \"#{@param[:label]}\" --useIsotopeEnvelopes #{@param[:useIsotopeEnvelopes]} --scanType #{@param[:scanType]} --minCharge #{@param[:minCharge]} --maxCharge #{@param[:maxCharge]} --minSnr #{@param[:minSnr]} --massAccuracy #{@param[:massAccuracy]} --checkForbiddenPeak #{@param[:checkForbiddenPeak]} --checkOverlappingPeaks #{@param[:checkOverlappingPeaks]} --absenceMassAccuracyFactor #{@param[:absenceMassAccuracyFactor]} --requireAbundance #{@param[:requireAbundance] * 0.01} --considerAbundance #{@param[:considerAbundance] * 0.01} --maxFitError #{@param[:maxFitError] * 0.01} --isotopePeaks #{@param[:isotopePeaks]} --logScale #{@param[:logScale]} #{csvOutputOptions} #{xhtmlOutputOptions} --spectraFiles \"#{ls_SpectraFile}\" --peptideFiles \"#{ls_PeptidesPath}\""
            runCommand(ls_Command, true)
            
            if @output[:qtraceCsv]
                File.open(@output[:qtraceCsv], 'a') do |lk_Out|
                    File.open(ls_CsvPath, 'r') do |lk_In|
                        ls_Header = lk_In.readline
                        lk_Out.puts ls_Header if lb_FirstRun
                        lk_In.each_line do |ls_Line|
                            lk_Out.puts ls_Line
                        end
                    end
                end
            end
            
            if @output[:xhtmlReport]
                File.open(@output[:xhtmlReport], 'a') do |lk_Out|
                    File.open(ls_XhtmlPath, 'r') do |lk_In|
                        contents = lk_In.read
                        contentStart = contents.index('<!-- BEGIN PEPTIDE')
                        if contentStart
                            if lb_NeedXhtmlHeader
                                header = contents[0, contentStart]
                                lk_Out.puts header
                                lb_NeedXhtmlHeader = false
                            end
                            contents = contents[contentStart, contents.size]
                            contentsEnd = contents.rindex('<!-- END PEPTIDE')
                            footer = contents[contentsEnd, contents.size]
                            contents = contents[0, contentsEnd]
                            lk_Out.puts contents
                            xhtmlFooter = footer
                        end
                    end
                end
            end
            lb_FirstRun = false
        end
        if @output[:xhtmlReport]
            File.open(@output[:xhtmlReport], 'a') do |lk_Out|
                unless lb_NeedXhtmlHeader
                    lk_Out.puts(xhtmlFooter)
                end
            end
        end
    end
end

script = QTrace.new

