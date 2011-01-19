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
require './include/ruby/ext/fastercsv'
require './include/ruby/misc'
require 'set'
require 'yaml'

class SubtractPsmScansFromXQuest < ProteomaticScript
    def run()
        psmScans = Set.new()
        @input[:psmList].each do |path|
            File::open(path, 'r') do |f|
                header = mapCsvHeader(f.readline)
                filenameIndex = header['filenameid']
                f.each_line do |line|
                    lineArray = line.parse_csv()
                    scan = lineArray[filenameIndex]
                    psmScans << scan
                end
            end
        end
        puts "Got #{psmScans.size} PSM scans."
        xQuestCount = 0
        removeCount = 0
        wroteHeader = false
        if @output[:croppedXQuestResults]
            File::open(@output[:croppedXQuestResults], 'w') do |fout|
                @input[:xQuestResults].each do |path|
                    File::open(path, 'r') do |f|
                        headerLine = f.readline
                        header = mapCsvHeader(headerLine)
                        unless wroteHeader
                            fout.puts headerLine
                            wroteHeader = true
                        end
                        spectrumIndex = header['spectrum']
                        f.each_line do |line|
                            lineArray = line.parse_csv()
                            spectrum = lineArray[spectrumIndex]
                            next unless spectrum
                            offset = spectrum.size
                            discardThis = false
                            while true
                                pos = spectrum.rindex('_', offset)
                                break unless pos
                                offset = pos - 1
                                snippet = spectrum[pos + 1, spectrum.size]
                                if psmScans.include?(snippet)
                                    discardThis = true
                                    break
                                end
                            end
                            xQuestCount += 1
                            if discardThis
                                removeCount += 1
                            else
                                fout.puts line
                            end
                        end
                    end
                end
            end
        end
        puts "Removed #{removeCount} of #{xQuestCount} xQuest scans because there were conflicting PSM scans."
    end
end

script = SubtractPsmScansFromXQuest.new
