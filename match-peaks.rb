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
require './include/ruby/formats'
require './include/ruby/misc'
require 'yaml'


class MatchPeaks < ProteomaticScript
    def run()
        allTargets = Hash.new
        formatString = "%1.#{@param[:targetMzDecimals]}f"
        @input[:targets].each do |path|
            if fileMatchesFormat(path, 'csv')
                File::open(path, 'r') do |f|
                    header = mapCsvHeader(f.readline)
                    unless header.include?('mz')
                        puts "Error: No 'm/z' column found in #{path}."
                        exit 1
                    end
                    f.each_line do |line|
                        lineArray = line.parse_csv()
                        mz = lineArray[header['mz']].to_f
                        charge = nil
                        charge = lineArray[header['charge']].to_i if header['charge']
                        description = nil
                        description = lineArray[header['description']] if header['description']
                        if mz > 0.0
                            mz = sprintf(formatString, mz)
                            allTargets[mz] ||= Set.new
                            allTargets[mz] << [charge, description]
                        end
                    end
                end
            else
                File::open(path, 'r') do |f|
                    f.each_line do |line|
                        mz = line.to_f
                        if mz > 0.0
                            mz = sprintf(formatString, mz)
                            allTargets[mz] ||= Set.new
                            allTargets[mz] << [nil, nil]
                        end
                    end
                end
            end
        end
        textTargetPath = tempFilename('match-peaks')
        File::open(textTargetPath, 'w') do |f|
            f.puts allTargets.keys.join("\n")
        end
        outFilePath = tempFilename('match-peaks')
        command = "\"#{ExternalTools::binaryPath('ptb.matchpeaks')}\" -o \"#{outFilePath}\" -a #{@param[:massAccuracy]} -s #{@param[:minSnr]} -c #{@param[:crop] / 100.0} -l \"#{@param[:msLevels]}\" \"#{textTargetPath}\" #{@input[:spectra].collect { |x| '"' + x + '"' }.join(' ')}"
        system(command)
        
        if @output[:results]
            File::open(@output[:results], 'w') do |fout|
                File::open(outFilePath, 'r') do |f|
                    headerLine = f.readline
                    fout.puts headerLine.strip + ',Charge,Description'
                    header = mapCsvHeader(headerLine)
                    f.each_line do |line|
                        lineArray = line.parse_csv()
                        targetMzString = lineArray[header['targetmz']]
                        lineArray[header['matchcount']] = (lineArray[header['matchcount']].to_i * allTargets[targetMzString].size).to_s
                        line = lineArray.to_csv()
                        allTargets[targetMzString].each do |x|
                            fout.puts line.strip + ",#{x[0]},\"#{x[1]}\""
                        end
                    end
                end
            end
        end
    end
end

lk_Object = MatchPeaks.new
