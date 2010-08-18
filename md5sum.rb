# Copyright (c) 2009 Michael Specht
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
require 'digest/md5'
require 'yaml'

class Md5Sum < ProteomaticScript

    def run()
        lk_Digest = Digest::MD5.new()
        files = @input[:files].sort do |a, b|
            File::basename(a) <=> File::basename(b)
        end
        print "Digesting #{files.size} file#{files.size > 1 ? 's' : ''}..."
        files.each do |path|
            File.open(path, 'rb') do |lk_File|
                while !lk_File.eof?
                    ls_Chunk = lk_File.read(8 * 1024 * 1024) # read 8M
                    lk_Digest << ls_Chunk
                end
            end
        end
        puts
        md5 = lk_Digest.hexdigest
        puts "The determined MD5 is #{md5}"
        unless @param[:assertMd5].empty?
            if @param[:assertMd5] != md5
                puts "Error: The determined MD5 does not match the asserted MD5."
                exit 1
            else
                puts "Success: The determined MD5 matches the asserted MD5."
            end
        end
    end
end

lk_Object = Md5Sum.new
