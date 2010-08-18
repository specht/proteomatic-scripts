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


class QuantitationAddProteins < ProteomaticScript
    def run()
        # test whether QE CSV headers are all the same
        ls_AllHeader = nil
        lk_AllHeader = nil
        @input[:quantitationEvents].each do |ls_InPath|
            File::open(ls_InPath, 'r') do |lk_In|
                ls_Header = lk_In.readline
                lk_Header = Set.new(mapCsvHeader(ls_Header).keys())
                ls_AllHeader ||= ls_Header
                lk_AllHeader = lk_Header
                if lk_Header != lk_AllHeader
                    puts "Error: The CSV header was not consistent throughout all quantitation event input files. The offending header line was #{ls_Header}."
                    exit 1
                end
            end
        end
        
        print 'Extracting peptides... '
        lk_AllPeptides = Set.new
        @input[:quantitationEvents].each do |ls_InPath|
            File::open(ls_InPath, 'r') do |lk_In|
                ls_Header = lk_In.readline
                lk_Header = mapCsvHeader(ls_Header)
                lk_In.each_line do |line|
                    values = line.parse_csv()
                    lk_AllPeptides << values[lk_Header['peptide']]
                end
            end
        end
        puts "found #{lk_AllPeptides.size}."
        
        ls_TempPath = tempFilename('filter-qe-add-proteins')
        FileUtils::mkpath(ls_TempPath)
        
        print 'Matching peptides to protein database... '
        ls_PeptidesPath = File::join(ls_TempPath, 'peptides.txt')
        ls_MatchResultsPath = File::join(ls_TempPath, 'results.yaml')
        File::open(ls_PeptidesPath, 'w') do |f|
            f.puts lk_AllPeptides.to_a.sort.join("\n")
        end
        ls_Command = "\"#{ExternalTools::binaryPath('ptb.matchpeptides')}\" --output \"#{ls_MatchResultsPath}\" --modelFiles #{@input[:geneModels].collect { |x| '"' + x + '"' }.join(' ')} --peptideFiles \"#{ls_PeptidesPath}\""
        system(ls_Command)
        puts 'done.'
        
        lk_MatchResults = YAML::load_file(ls_MatchResultsPath)

        # lk_PeptideToProtein contains peptide -> protein if the mapping
        # is exactly 1:1
        lk_PeptideToProtein = Hash.new
        lk_AllPeptides.each do |ls_Peptide|
            if lk_MatchResults[ls_Peptide]
                if lk_MatchResults[ls_Peptide].size == 1
                    lk_PeptideToProtein[ls_Peptide] = lk_MatchResults[ls_Peptide].keys.first
                end
            end
        end
        
        if @output[:results]
            File::open(@output[:results], 'w') do |lk_Out|
                 print 'Writing protein tagged quantitation events...'
                li_InCount = 0
                li_NoMatchCount = 0
                li_MultiMatchCount = 0
                lk_Out.puts ls_AllHeader.strip + ',protein'
                @input[:quantitationEvents].each do |ls_InPath|
                    File::open(ls_InPath, 'r') do |lk_In|
                        ls_Header = lk_In.readline
                        lk_Header = mapCsvHeader(ls_Header)
                        lk_In.each_line do |ls_Line|
                            li_InCount += 1
                            lk_Line = ls_Line.parse_csv()
                            ls_Peptide = lk_Line[lk_Header['peptide']]
                            if (lk_PeptideToProtein[ls_Peptide] == nil)
                                if ((!lk_MatchResults[ls_Peptide]) || lk_MatchResults[ls_Peptide].empty?)
                                    li_NoMatchCount += 1
                                else
                                    li_MultiMatchCount += 1
                                end
                            else
                                lk_Line << lk_PeptideToProtein[ls_Peptide]
                                lk_Out.puts lk_Line.to_csv()
                            end
                        end
                    end
                end
                puts
                puts "Discarded #{li_NoMatchCount} QE (#{sprintf('%1.1f%%', li_NoMatchCount.to_f / li_InCount * 100.0)}) because the peptide could not be matched any protein sequence." if li_NoMatchCount > 0
                puts "Discarded #{li_MultiMatchCount} QE (#{sprintf('%1.1f%%', li_MultiMatchCount.to_f / li_InCount * 100.0)}) because the peptide matched to multiple proteins." if li_MultiMatchCount > 0
            end
        end
    end
end

lk_Object = QuantitationAddProteins.new
