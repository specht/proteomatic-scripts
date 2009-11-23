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
require 'include/ruby/externaltools'
require 'include/ruby/misc'
require 'yaml'
require 'fileutils'

class MultiplyFingerprint < ProteomaticScript

	def run()
		lk_Mask = Hash.new
		File::open(@input[:mask].first, 'r') do |f|
			header = mapCsvHeader(f.readline)
			f.each_line do |line|
				lineArray = line.parse_csv()
				key = "#{lineArray[header['a']].to_i}/#{lineArray[header['d']].to_i}"
				lk_Mask[key] = lineArray[header['amount']].to_f
			end
		end
		@output.each_pair do |inPath, outPath|
			File::open(outPath, 'w') do |lk_Out|
				File::open(inPath) do |lk_In|
					headerLine = lk_In.readline
					header = mapCsvHeader(headerLine)
					lk_Out.puts headerLine
					lk_In.each_line do |line|
						lineArray = line.parse_csv()
						key = "#{lineArray[header['a']].to_i}/#{lineArray[header['d']].to_i}"
						amount = lineArray[header['amount']].to_f
						factor = lk_Mask[key]
						factor ||= 0.0
						amount *= factor
						lineArray[header['amount']] = amount
						lk_Out.puts lineArray.to_csv()
					end
				end
			end
		end
	end
end

lk_Object = MultiplyFingerprint.new
