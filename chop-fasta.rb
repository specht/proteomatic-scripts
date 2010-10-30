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
require './include/ruby/fasta'

class ChopFasta < ProteomaticScript
    def run()
        windowShift = (@param[:windowSize] * (1.0 - (@param[:windowShift] / 100.0))).to_i
        puts "Using a window size of #{@param[:windowSize]} and a shift of #{windowShift}."
        if windowShift == 0
            puts "Error: Window shift cannot be 0."
            exit(1)
        end
        @output.each_pair do |inPath, outPath|
            File::open(outPath, 'w') do |fout|
                File::open(inPath, 'r') do |fin|
                    fastaIterator(fin) do |id, sequence|
                        index = 0
                        while index < sequence.size
                            chunk = sequence[index, @param[:windowSize]]
                            fout.puts ">#{id}_offset_#{index}"
                            fout.puts chunk
                            index += windowShift
                        end
                    end
                end
            end
        end
    end
end

lk_Object = ChopFasta.new
