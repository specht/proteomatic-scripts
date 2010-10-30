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


class Highlight < ProteomaticScript
    def run()
        # load items to be highlighted
        items = Set.new
        @input[:items].each do |path|
            File::open(path, 'r') do |f|
                f.each_line do |line|
                    item = line.strip
                    items << Regexp.new('(' + Regexp.escape(item) + ')', @param[:caseSensitive] ? nil : Regexp::IGNORECASE) unless item.empty?
                end
            end
        end
        
        puts "Got #{items.size} items to highlight."
        
        @output.each do |inPath, outPath|
            File::open(outPath, 'w') do |fo|
                File::open(inPath, 'r') do |fi|
                    lineBatch = ''
                    fi.each_line do |line|
                        lineBatch += line
                        if (lineBatch.size >= 8 * 1024 * 1024)
                            items.each do |item|
                                lineBatch.gsub!(item, "<span style='background-color: #8ae234;'>\\1</span>")
                            end
                            fo.puts lineBatch
                            lineBatch = ''
                        end
                    end
                    unless lineBatch.empty?
                        items.each do |item|
                            lineBatch.gsub!(item, "<span style='background-color: #8ae234;'>\\1</span>")
                        end
                        fo.puts lineBatch
                    end
                end
            end
        end
    end
end

lk_Object = Highlight.new
