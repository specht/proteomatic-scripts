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
require 'set'


class CreateFasta < ProteomaticScript
    def run()
        entries = Set.new
        @input[:sequences].each do |path|
            thisEntries = Set.new(File::read(path).split("\n"))
            entries |= thisEntries
        end
        if @output[:fasta]
            File::open(@output[:fasta], 'w') do |f|
                entries.each do |x|
                    f.puts ">#{@param[:prefix]}#{x}"
                    f.puts "#{x}"
                end
            end
        end
    end
end

lk_Object = CreateFasta.new
