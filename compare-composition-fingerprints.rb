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

require 'include/proteomatic'
require 'include/externaltools'
require 'include/misc'
require 'include/ext/fastercsv'
require 'yaml'
require 'fileutils'

class CompareCompositionFingerprints < ProteomaticScript
	def run()
		lk_Fingerprint = Hash.new
		@input[:compositionFingerprint].each do |ls_Path|
			sum = 0.0
			File::open(ls_Path) do |f|
				header = mapCsvHeader(f.readline)
				f.each_line do |line|
					lineArray = line.parse_csv()
					lk_Fingerprint[ls_Path] ||= Hash.new
					key = "#{lineArray[header['a']].to_i}/#{lineArray[header['d']].to_i}"
					lk_Fingerprint[ls_Path][key] ||= 0.0
					amount = lineArray[header['amount']].to_f
					lk_Fingerprint[ls_Path][key] += amount
					sum += lk_Fingerprint[ls_Path][key]
				end
			end
			# normalize fingerprint
			lk_Fingerprint[ls_Path].keys.each do |key|
				lk_Fingerprint[ls_Path][key] /= sum
			end
		end
		if @output[:distances]
			File::open(@output[:distances], 'w') do |lk_Out|
				lk_Out.puts "Distance,A,B"
				(0...lk_Fingerprint.keys.size).each do |a|
					(a...lk_Fingerprint.keys.size).each do |b|
						next if a == b
						aPath = @input[:compositionFingerprint][a]
						bPath = @input[:compositionFingerprint][b]
						ld_Distance = 0.0
						lk_AllKeys = Set.new(lk_Fingerprint[aPath].keys) | Set.new(lk_Fingerprint[bPath].keys)
						lk_AllKeys.each do |key|
							aAmount = lk_Fingerprint[aPath][key]
							bAmount = lk_Fingerprint[bPath][key]
							aAmount ||= 0.0
							bAmount ||= 0.0
							ld_Distance += (aAmount - bAmount) ** 2.0
						end
						ld_Distance = ld_Distance ** 0.5
						lk_Out.puts "#{sprintf('%f', ld_Distance)},#{File::basename(aPath)},#{File::basename(bPath)}"
					end
				end
			end
		end
	end
end

lk_Object = CompareCompositionFingerprints.new
