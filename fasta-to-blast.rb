#! /usr/bin/env ruby
# Copyright (c) 2010-2012 Michael Specht, Till Bald
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
            
            if RUBY_PLATFORM.downcase.include?("mswin")
                # make temp dir in user directory (necessary as network drives somehow cannot handle short names. Short names are necessary for formatdb as spaces are handled arkward.)
                tempDir = Dir.mktmpdir('fasta-to-blast-')
            elsif inPath.include?(" ")
                # spaces do not work in non windows os either, so we need chose the temp dir
                tempDir = Dir.mktmpdir('fasta-to-blast-')
            else
                # make temp dir in output directory
                tempDir = tempFilename('fasta-to-blast-')
                FileUtils::mkdir(tempDir)
            end
            
            FileUtils::cp(inPath, tempDir)
            tempInputPath = File::join(tempDir, File::basename(inPath))
            if RUBY_PLATFORM.downcase.include?("mswin")
               tempInputPath = get_short_win32_filename(tempInputPath)
            end
            createBlastDatabase(tempInputPath)
            
            # convert filenames on Windows (formatdb cannot handle spaces)
            longName = File::basename(inPath)
            filename = longName
            if RUBY_PLATFORM.downcase.include?("mswin")
                filename = File::basename(get_short_win32_filename(File::join(tempDir, filename)))
            end

            FileUtils::copy(File::join(tempDir, filename) + '.phr', File::join(File::dirname(outPath), longName) + '.phr');
            FileUtils::copy(File::join(tempDir, filename) + '.pin', File::join(File::dirname(outPath), longName) + '.pin');
            FileUtils::copy(File::join(tempDir, filename) + '.psq', File::join(File::dirname(outPath), longName) + '.psq');
            
            FileUtils::rm_rf(tempDir)
        end
    end
    
    def get_short_win32_filename(long_name)
        require 'win32api'
        win_func = Win32API.new("kernel32","GetShortPathName","PPL"," L")
        buf = 0.chr * 256
        buf[0..long_name.length-1] = long_name
        win_func.call(long_name, buf, buf.length)
        return buf.split(0.chr).first
    end
end

script = FastaToBlast.new
