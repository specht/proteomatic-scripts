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
require './include/ruby/externaltools'
require './include/ruby/formats'
require 'net/http'
require 'net/ftp'
require 'yaml'
require 'set'


class RunGpf < ProteomaticScript
    def run()
        @mk_Peptides = Set.new
        
        ls_GenomePath = ''
        ls_GenomePath = $gb_FixedGenomes ? @param[:genome] : @input[:genome].first
        
        def handlePeptide(as_Peptide, af_Mass = nil)
            ls_Id = "peptide=#{as_Peptide}"
            ls_Id += ";precursorMass=#{af_Mass}" if af_Mass
            @mk_Peptides.add(ls_Id)
        end
        
        @input[:predictions].each do |ls_Path|
            if (fileMatchesFormat(ls_Path, 'gpf-queries'))
                File.open(ls_Path, 'r') do |lk_File|
                    lk_File.each do |ls_Line|
                        ls_Line.strip!
                        next if ls_Line.empty?
                        handlePeptide(ls_Line)
                    end
                end
            elsif (fileMatchesFormat(ls_Path, 'txt'))
                File.open(ls_Path, 'r') do |lk_File|
                    lk_File.each do |ls_Line|
                        ls_Line.strip!
                        next if ls_Line.empty?
                        handlePeptide(ls_Line)
                    end
                end
            else
                File.open(ls_Path, 'r') do |lk_File|
                    lf_Mass = nil
                    ls_Peptide = ''
                    lk_File.each do |ls_Line|
                        ls_Line.strip!
                        if (ls_Line[0, 1] == '>')
                            handlePeptide(ls_Peptide, lf_Mass) unless ls_Peptide.empty?
                            lk_Line = ls_Line.split(' ')
                            lf_Mass = nil
                            if lk_Line.size > 3
                                lf_Mass = Float(lk_Line[lk_Line.size - 3].strip)
                                li_Charge = Integer(lk_Line[lk_Line.size - 2].strip)
                                lf_Mass = lf_Mass * li_Charge - 1.007825 * (li_Charge - 1)
                            end
                            ls_Peptide = ''
                        else
                            ls_Peptide += ls_Line
                        end
                    end
                    handlePeptide(ls_Peptide, lf_Mass) unless ls_Peptide.empty?
                end
            end
        end
        
        ls_Query = @mk_Peptides.to_a.sort.join("\n")
        
        ls_GpfOptions = "masses #{@param[:masses]} protease #{@param[:protease]} massError #{@param[:massError]} searchSimilar #{@param[:searchSimilar]} searchIntrons #{@param[:searchIntrons]} maxIntronLength #{@param[:maxIntronLength]} minChainLength #{@param[:minChainLength]} fullDetails yes"
        
        ls_QueryFile = tempFilename("gpf-queries-")
        File::open(ls_QueryFile, 'w') { |lk_File| lk_File.write(ls_Query) }
        
        ls_ResultFile = tempFilename("gpf-results-");
        
        ls_CsvPathSwitch = ''
        if @output[:csvResults]
            ls_CsvPathSwitch = " --csvResultsPath \"#{@output[:csvResults]}\" "
        end

        ls_Command = "#{ExternalTools::binaryPath('gpf.gpfbatch')} #{ls_GpfOptions} --yamlResultsPath \"#{ls_ResultFile}\" #{ls_CsvPathSwitch} \"#{ls_GenomePath}\" \"#{ls_QueryFile}\""
        runCommand(ls_Command)
        
        FileUtils::cp(ls_ResultFile, @output[:yamlResults]) if @output[:yamlResults]
        
        lk_Hits = Set.new
        
        ls_LineBatch = ''
        File::open(ls_ResultFile, 'r').each_line do |ls_Line|
            if (ls_Line[0, 1] != ' ' && !ls_LineBatch.empty?)
                # handle line batch
                lk_ResultPart = YAML::load(ls_LineBatch)
                lk_ResultPart.each do |ls_Key, lk_Result|
                    next unless lk_Result.class == Array
                    next if lk_Result.empty?
                    lk_Result.each { |lk_Hit| lk_Hits.add(lk_Hit['peptide']) }
                end
                ls_LineBatch = ''
            end
            ls_LineBatch += ls_Line
        end
        if (!ls_LineBatch.empty?)
            # handle line batch
            lk_ResultPart = YAML::load(ls_LineBatch)
            lk_ResultPart.each do |ls_Key, lk_Result|
                next unless lk_Result.class == Array
                next if lk_Result.empty?
                lk_Result.each { |lk_Hit| lk_Hits.add(lk_Hit['peptide']) }
            end
            ls_LineBatch = ''
        end
        
        puts "GPF found #{lk_Hits.size} hits."
        
        if @output[:gpfPeptides]
            File.open(@output[:gpfPeptides], 'w') do |lk_Out|
                lk_Hits.to_a.sort.each { |ls_Peptide| lk_Out.print ">gpf__#{ls_Peptide}\n#{ls_Peptide}\n" }
            end
        end
    end
end

script = RunGpf.new
