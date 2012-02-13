#! /usr/bin/env ruby
# Copyright (c) 2012 Michael Specht
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
require 'yaml'
require 'set'


class FastqDump < ProteomaticScript
    def run()
        @output.each do |inPath, outPath|
            command = "#{binaryPath('sratoolkit.fastq-dump')} --outdir \"#{File::dirname(outPath)}\" \"#{inPath}\""
            puts "Converting SRA..."
            system(command)
        end
    end
end

script = FastqDump.new
