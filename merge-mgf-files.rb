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

require 'include/ruby/proteomatic'
require 'include/ruby/externaltools'
require 'include/ruby/misc'
require 'include/ruby/ext/fastercsv'
require 'yaml'
require 'set'
require 'fileutils'

class MergeMgfFiles < ProteomaticScript
    
    def simpleMerge(paths)
        headerLine = nil
        File::open(@output[:merged], 'w') do |fout|
            totalCount = 0
            @input[:in].each do |path|
                File::open(path, 'r') do |f|
                    f.each_line do |line|
                        fout.puts line
                    end
                end
            end
            fout.puts
        end
    end
    
    def run()
        unless @output[:merged]
            puts "Notice: Doing nothing, because no output file has been requested."
            exit 0
        end
        
        simpleMerge(@input[:in])
    end
end

lk_Object = MergeMgfFiles.new
