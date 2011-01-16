#! /usr/bin/env ruby
# Copyright (c) 2007-2010 Michael Specht
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
require './include/ruby/fasta'
require 'set'

class DigestProtein < ProteomaticScript
    def digestProtein(_protein)
        protein = _protein.dup
        # remove invalid characters
        protein.gsub!(/[^GASPVTCLINDQKEMHFRYW]/, '')
        # insert spaces at tryptic cleavage sites
        # this is done twice because after the first step,
        # there might still be blocks like KK, KR, RK, or RR
        2.times { protein.gsub!(/([RK])([^P])/, "\\1 \\2") }
        parts = protein.split(' ')
        peptides = Set.new
        (0..@param[:mc]).each do |length|
            (0...parts.size-length).each do |offset|
                peptide = parts[offset, length + 1].join()
                peptides << peptide if peptide.size >= @param[:minLength]
            end
        end
        return peptides
    end

    def run()
        peptides = Set.new
        unless @param[:protein].empty?
            peptides |= digestProtein(@param[:protein])
        end
        count = 0
        @input[:sequences].each do |path|
            File::open(path, 'r') do |f|
                fastaIterator(f) do |id, sequence|
                    count += 1
                    peptides |= digestProtein(sequence)
                    print "\rDigesting #{count} sequences, got #{peptides.size} peptides..."
                end
            end
        end
        puts "\rDigesting #{count} sequences, got #{peptides.size} peptides..."
        if peptides.size == 0
            puts "No resulting peptides."
        elsif peptides.size <= 200
            puts peptides.to_a.sort.join("\n")
        else
            puts "Got #{peptides.size} peptides."
        end
        # also write peptides to output file if requested
        if @output[:results]
            File::open(@output[:results], 'w') do |f|
                f.puts peptides.to_a.sort.join("\n")
            end
        end
    end
end

lk_Object = DigestProtein.new
