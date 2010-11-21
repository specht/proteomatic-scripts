# Copyright (c) 2010 Michael Specht
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
require './include/ruby/misc'
require './include/ruby/ext/fastercsv'
require 'yaml'
require 'set'


class ExtractGpfPeptides < ProteomaticScript
    def run()
        immediatePeptides = Set.new
        intronSplitPeptides = Set.new
        tripletSplitPeptides = Set.new
        @input[:in].each do |path|
            File::open(path, 'r') do |f|
                header = mapCsvHeader(f.readline)
                unless header.include?('assembly')
                    puts "Error: No 'assembly' column found in #{path}."
                    exit 1
                end
                f.each_line do |line|
                    lineArray = line.parse_csv()
                    assembly = lineArray[header['assembly']]
                    originalAssembly = assembly.dup
                    parts = []
                    if assembly[0, 1] == '{'
                        # new assembly: {cre4-tag5/chromosome1}+819374:19,820977:17
                        assembly.sub!(/\{.+\}/, '')
                        unless ['-', '+'].include?(assembly[0, 1])
                            puts "Error: Not a valid assembly: #{originalAssembly}"
                            exit 1
                        end
                        assembly = assembly[1, assembly.size - 1]
                        parts = assembly.split(',')
                    else
                        # old assembly: cre4;-56830916:3,56829598:33
                        assembly.sub!(/.+;/, '')
                        unless ['-', '+'].include?(assembly[0, 1])
                            puts "Error: Not a valid assembly: #{originalAssembly}"
                            exit 1
                        end
                        assembly = assembly[1, assembly.size - 1]
                        parts = assembly.split(',')
                    end
                    peptide = lineArray[header['peptide']]
                    if parts.size == 1
                        immediatePeptides << peptide
                    else
                        firstExonLength = parts[0].split(':')[1].to_i
                        intronSplitPeptides << peptide
                        tripletSplitPeptides << peptide if (firstExonLength % 3) != 0
                    end
                end
            end
        end
        puts "Immediate peptides: #{immediatePeptides.size}."
        puts "Intron split peptides: #{intronSplitPeptides.size}."
        puts "Triplet split peptides: #{tripletSplitPeptides.size}."
        File::open(@output[:immediatePeptides], 'w') { |f| f.puts immediatePeptides.to_a.sort.join("\n") } if @output[:immediatePeptides]
        File::open(@output[:intronSplitPeptides], 'w') { |f| f.puts intronSplitPeptides.to_a.sort.join("\n") } if @output[:intronSplitPeptides]
        File::open(@output[:tripletSplitPeptides], 'w') { |f| f.puts tripletSplitPeptides.to_a.sort.join("\n") } if @output[:tripletSplitPeptides]
    end
end


lk_Object = ExtractGpfPeptides.new
