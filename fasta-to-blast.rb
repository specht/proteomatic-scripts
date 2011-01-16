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
require './include/ruby/fasta'
require 'fileutils'


class FastaToBlast < ProteomaticScript
    def run()
        @output.each do |inPath, outPath|
            puts 'Converting database to BLAST format...'
            tempDir = tempFilename('fasta-to-blast-')
            FileUtils::mkdir(tempDir)
            FileUtils::cp(inPath, tempDir)
            createBlastDatabase(File::join(tempDir, File::basename(inPath)))
            FileUtils::mv(File::join(tempDir, File::basename(inPath)) + '.phr', File::dirname(outPath));
            FileUtils::mv(File::join(tempDir, File::basename(inPath)) + '.pin', File::dirname(outPath));
            FileUtils::mv(File::join(tempDir, File::basename(inPath)) + '.psq', File::dirname(outPath));
        end
    end
end

lk_Object = FastaToBlast.new
