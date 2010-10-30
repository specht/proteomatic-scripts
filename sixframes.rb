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
require './include/ruby/externaltools'
require 'yaml'
require 'set'


class SixFrames < ProteomaticScript
    def run()
        if @output[:outputDatabase]
            print 'Creating six frame translation...'
            parts = Array.new
            @input[:input].each do |path|
                outFilename = @output[:outputDatabase]
                if @input[:input].size > 1
                    outFilename = tempFilename('sixframes') 
                    parts << outFilename
                end
                ls_Command = "#{ExternalTools::binaryPath('ptb.translatedna')} --output \"#{outFilename}\" --frames \"#{@param[:frames]}\" --headerFormat \"#{@param[:format]}\" \"#{path}\""
                runCommand(ls_Command, true)
            end
            unless parts.empty?
                File::open(@output[:outputDatabase], 'w') do |f|
                    parts.each do |inPath|
                        File::open(inPath, 'r') do |fi|
                            while !(fi.eof?)
                                buffer = fi.read(8 * 1024 * 1024)
                                f.write(buffer)
                            end
                        end
                        FileUtils::rm(inPath)
                    end
                end
            end
            puts 'done.'
        end
    end
end

lk_Object = SixFrames.new
