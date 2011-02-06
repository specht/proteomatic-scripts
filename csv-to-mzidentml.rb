#! /usr/bin/env ruby
# Copyright (c) 2011 Michael Specht
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
require 'fileutils'

class CsvToMzIdentML < ProteomaticScript
    def run()
        @output.each do |inPath, outPath|
            puts "Converting #{inPath}..."
            paramFilePath = tempFilename('param-')
            tempFilePath = tempFilename('out-')
            # write parameter file for csv2mzidentml Perl script, using default values
            File::open(paramFilePath, 'w') do |f|
                f.puts "Param,cvTerm,Accession,Value"
                f.puts "Software name,OMSSA,MS:1001475,N/A,,"
                f.puts "Provider,N/A,N/A,N/A,,"
                f.puts "Parent mass type,parent mass type mono,MS:1001211,N/A,,"
                f.puts "Fragment mass type,fragment mass type mono,MS:1001256,N/A,,"
                f.puts "Enzyme,Trypsin,MS:1001251,N/A,,"
                f.puts "Missed cleavages,N/A,N/A,2,,"
                f.puts "Fragment search tolerance plus,search tolerance plus value,MS:1001412,0.5,,"
                f.puts "Fragment search tolerance minus,search tolerance minus value,MS:1001413,0.5,,"
                f.puts "Parent search tolerance plus,search tolerance plus value,MS:1001412,0.02,,"
                f.puts "Parent search tolerance minus,search tolerance minus value,MS:1001413,0.02,,"
                f.puts "PSM threshold,no threshold,MS:1001494,N/A,,"
                f.puts "Input file format,OMSSA csv file,MS:1001399,N/A,,"
                f.puts "Database file format,FASTA format,MS:1001348,N/A,,"
                f.puts "Decoy database regex,decoy DB accession regexp,MS:1001283,__td__decoy_,,"
                f.puts "Spectra data file format,Mascot MGF file,MS:1001062,N/A,,"
                f.puts "Spectrum ID format,multiple peak list nativeID format,MS:1000774,N/A,,"
            end
            
            command = "\"#{ExternalTools::binaryPath('lang.perl.perl')}\" " + 
                    "\"#{ExternalTools::binaryPath('ext.web-based-multiplesearch.csv2mzidentml')}\" " +
                    "\"#{inPath}\" \"#{paramFilePath}\" \"#{tempFilePath}\""
            runCommand(command)
            
            # now remove some information from the input file which we cannot provide at this point
            File::open(outPath, 'w') do |fout|
                cut = []
                cutList = ['provider', 'auditcollection', 'additionalsearchparams', 'enzymes', 'masstable', 'fragmenttolerance', 'parenttolerance']
                File::open(tempFilePath, 'r') do |f|
                    f.each_line do |line|
                        test = line.downcase.strip
                        if test[0, 1] == '<'
                            tag = /\w+/.match(test)
                            if tag
                                tag = tag.to_a.first
                                (test[0, 2] == '</') ? nil : cut << tag if cutList.include?(tag)
                            end
                        end
                        fout.puts line if cut.empty?
                        if test[0, 1] == '<'
                            tag = /\w+/.match(test)
                            if tag
                                tag = tag.to_a.first
                                (test[0, 2] == '</') ? cut.pop : nil if cutList.include?(tag)
                            end
                        end
                    end
                end
            end
            
            # delete temporary files
            FileUtils::rm_f(paramFilePath)
            FileUtils::rm_f(tempFilePath)
        end
    end
end

script = CsvToMzIdentML.new
