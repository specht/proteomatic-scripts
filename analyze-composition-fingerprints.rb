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
require 'include/ruby/ext/fastercsv'
require 'yaml'
require 'fileutils'

class AnalyzeCompositionFingerprints < ProteomaticScript
    def run()
        lk_Fingerprint = Hash.new
        @input[:compositionFingerprint].each do |ls_Path|
            maximum = 0.0
            File::open(ls_Path) do |f|
                header = mapCsvHeader(f.readline)
                drKey = 'd'
                drKey = 'r' unless header[drKey]
                f.each_line do |line|
                    lineArray = line.parse_csv()
                    lk_Fingerprint[ls_Path] ||= Hash.new
                    key = "#{lineArray[header['a']].to_i}/#{lineArray[header[drKey]].to_i}"
                    lk_Fingerprint[ls_Path][key] ||= 0.0
                    amount = lineArray[header['amount']].to_f
                    lk_Fingerprint[ls_Path][key] += amount
                    maximum = lk_Fingerprint[ls_Path][key] if lk_Fingerprint[ls_Path][key] > maximum
                end
            end
            # normalize fingerprint
            sum = 0.0
            averageDP = 0.0
            averageDA = 0.0
            aSum = 0.0
            dSum = 0.0
            lk_Fingerprint[ls_Path].keys.each do |key|
                lk_Fingerprint[ls_Path][key] /= maximum
                sum += lk_Fingerprint[ls_Path][key]
                ad = key.split('/')
                a = ad[0].to_i
                d = ad[1].to_i
                relativeDA = a.to_f / (a + d)
                # add relative to average DA (weighted!)
                averageDA += relativeDA * lk_Fingerprint[ls_Path][key]
                averageDP += (a + d).to_f * lk_Fingerprint[ls_Path][key]
                aSum += a.to_f * lk_Fingerprint[ls_Path][key]
                dSum += d.to_f * lk_Fingerprint[ls_Path][key]
            end
            averageDA /= sum
            averageDP /= sum
            puts "DP #{sprintf('%5.2f', averageDP)} / DA #{sprintf('%5.2f', averageDA * 100.0)}% / DA (mass) #{sprintf('%5.2f', aSum / (aSum + dSum) * 100.0)}% / #{File::basename(ls_Path)}"
        end
    end
end

lk_Object = AnalyzeCompositionFingerprints.new
