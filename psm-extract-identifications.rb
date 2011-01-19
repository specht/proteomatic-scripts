#! /usr/bin/env ruby
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
require './include/ruby/ext/fastercsv'
require './include/ruby/misc'
require 'set'
require 'yaml'


class PsmExtractIdentifications < ProteomaticScript
    def run()
        @output.each_pair do |inPath, outPath|
            File::open(outPath, 'w') do |fout|
                puts File::basename(inPath)
                results = loadPsm(inPath)
                x = []
                if @param[:scope] == 'protein'
                    x = results[:proteins].keys
                else
                    x = results[:peptideHash].keys
                end
                x = x.to_a unless x.class == Array
                fout.puts x.sort.join("\n")
            end
        end
    end
end

script = PsmExtractIdentifications.new
