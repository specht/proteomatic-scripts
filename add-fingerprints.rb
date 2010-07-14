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

class AddFingerprints < ProteomaticScript

	def run()
		lk_Sum = Hash.new
		@input[:fingerprints].each do |inPath|
			File::open(inPath) do |lk_In|
				headerLine = lk_In.readline
				header = mapCsvHeader(headerLine)
                drKey = 'd'
                drKey = 'r' unless header[drKey]
				lk_In.each_line do |line|
					lineArray = line.parse_csv()
					key = "#{lineArray[header['a']].to_i}/#{lineArray[header[drKey]].to_i}"
					amount = lineArray[header['amount']].to_f
					lk_Sum[key] ||= 0.0
					lk_Sum[key] += amount
				end
			end
		end
		if @output[:sumFingerprint]
			File::open(@output[:sumFingerprint], 'w') do |lk_Out|
				lk_Out.puts "Amount,A,D"
				lk_Sum.keys.each do |key|
					a = key.split('/')[0]
					d = key.split('/')[1]
					lk_Out.puts "#{lk_Sum[key]},#{a},#{d}"
				end
			end
		end
	end
end

lk_Object = AddFingerprints.new
