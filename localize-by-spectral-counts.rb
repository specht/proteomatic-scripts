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
require './include/ruby/evaluate-omssa-helper'
require './include/ruby/misc'
require 'yaml'
require 'fileutils'

class LocalizeBySpectralCounts < ProteomaticScript
    def run()
        itemKey = (@param[:scope] + 's').intern
        spectralCounts = Hash.new
        puts "Reading PSM lists..."
        [:a, :b].each do |locKey|
            @input[locKey].each do |path|
                results = loadPsm(path, :silent => true)
                results[:spectralCounts][itemKey].each_pair do |item, counts|
                    spectralCounts[item] ||= Hash.new
                    spectralCounts[item][locKey] ||= 0
                    spectralCounts[item][locKey] += counts[:total]
                end
            end
        end
        puts "Performing localization..."
        resultFile = nil
        resultFile = File::open(@output[:results], 'w') if @output[:results]
        localizedCount = 0
        resultFile.puts "#{@param[:scope].capitalize},A scan count,B scan count,Ratio" if resultFile
        spectralCounts.each_pair do |item, valuesAB|
            aCount = valuesAB[:a]
            bCount = valuesAB[:b]
            aCount ||= 0
            bCount ||= 0
            accept = false
            ratio = nil
            if (bCount == 0)
                # no ratio can be calculated, use min scan count
                accept = (aCount >= @param[:minAScanCount])
            else
                # determine ratio
                ratio = aCount.to_f / bCount.to_f
                accept = (ratio >= @param[:minRatio])
            end
            if accept
                localizedCount += 1
                resultFile.puts "\"#{item}\",#{aCount},#{bCount},#{ratio}" if resultFile
            end
        end
        resultFile.close if resultFile
        puts "Localized #{localizedCount} of #{spectralCounts.size} #{@param[:scope]}s."
    end
end

lk_Object = LocalizeBySpectralCounts.new
