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
require './include/ruby/evaluate-omssa-helper'
require './include/ruby/externaltools'
require './include/ruby/fasta'
require './include/ruby/formats'
require './include/ruby/misc'
require 'bigdecimal'
require 'fileutils'
require 'yaml'


class ExtractOmssaResults < ProteomaticScript
    def run()
        # get peptides from PSM list
        results = loadPsm(@input[:psmFile].first, :silent => false) 
        allProteins = results[:proteins].keys.reject do |x|
            results[:proteins][x].size < @param[:distinctPeptides]
        end
        modPeptides = results[:peptideHash].keys.reject do |x|
            results[:peptideHash][x][:mods].empty?
        end
        if @output[:allPeptides]
            File::open(@output[:allPeptides], 'w') do |f|
                f.puts results[:peptideHash].keys.to_a.sort.join("\n")
            end
        end
        if @output[:modPeptides]
            File::open(@output[:modPeptides], 'w') do |f|
                f.puts modPeptides.sort.join("\n")
            end
        end
        if @output[:allProteins]
            File::open(@output[:allProteins], 'w') do |f|
                f.puts allProteins.to_a.sort.join("\n")
            end
        end
        if @output[:modProteins]
            File::open(@output[:modProteins], 'w') do |f|
                modPeptidesSet = Set.new(modPeptides)
                allModProteins = allProteins.reject do |x|
                    someModified = false
                    results[:proteins][x].each do |x|
                        someModified = true if modPeptidesSet.include?(x)
                    end
                    !someModified
                end
                f.puts allModProteins.to_a.sort.join("\n")
            end
        end
    end
end

lk_Object = ExtractOmssaResults.new
