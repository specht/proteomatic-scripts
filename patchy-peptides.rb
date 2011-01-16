#! /usr/bin/env ruby
# Copyright (c) 2007-2008 Michael Specht
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
require './include/ruby/ext/fastercsv'
require 'set'
require 'yaml'
require 'fileutils'

class PatchyPeptides < ProteomaticScript
    
    def handleEntry(id, entry)
        return if (id.empty?) || (entry.empty?)
        entry.gsub!('I', 'L')
        idList = id.split(' ')
        key = idList.join('_')
        key = idList[0, idList.size - 3].join('_') if idList.size > 3
        score = 0.0
        if (idList[-1][0, 2] == '<1')
            score = 0.0
        else
            score = idList[-1].sub('%', '').to_f
        end
        return if score < @param[:minScore]
        @entryCount += 1
        if ((@entryCount % 100) == 0)
            print "\rReading de novo peptides... #{@entryCount}"
        end
        @entries[key] ||= Set.new
        @entries[key] << entry
        (@param[:minOverlap]...entry.size).each do |length|
            @leftTags[length] ||= Hash.new
            @rightTags[length] ||= Hash.new
            leftTag = entry[0, length]
            @leftTags[length][leftTag] ||= Set.new
            @leftTags[length][leftTag] << key
            rightTag = entry[-length, length]
            @rightTags[length][rightTag] ||= Set.new
            @rightTags[length][rightTag] << key
        end
    end

    def printIgorPeptide(igorDescription)
        length = 0
        igorDescription.each do |part|
            right = part[1] + part[0].size
            length = right if right > length
        end
        igor = ''
        counts = Array.new
        length.times { igor += '*'; counts << 0 }
        igorDescription.each do |part|
            igor[part[1], part[0].size] = part[0]
            (0...part[0].size).each do |i|
                counts[i + part[1]] += 1
            end
        end
        oldCount = 0
        result = ''
        (0...length).each do |i|
            result += '[' if (oldCount < counts[i])
            result += ']' if (oldCount > counts[i])

            result += igor[i, 1]
            oldCount = counts[i]
        end
        result += ']'
        return result
    end


    def igorPeptideOverlapStatistics(igorDescription)
        overlaps = Array.new
        igorDescription.each do |a|
            igorDescription.each do |b|
                next if a == b
                next if a.join(',') > b.join(',')
                a0 = a[1]
                a1 = a[1] + a[0].size
                b0 = b[1]
                b1 = b[1] + b[0].size
                overlaps << a1 - b0 if (a1 > b0) && (a0 < b0)
                overlaps << b1 - a0 if (b1 > a0) && (b0 < a0)
            end
        end
        overlaps.sort!
        mean = 0.0
        overlaps.each { |x| mean += x }
        mean /= overlaps.size
        return overlaps.first, mean, overlaps.last
    end


    def igorPeptideToString(igorDescription)
        length = 0
        igorDescription.each do |part|
            right = part[1] + part[0].size
            length = right if right > length
        end
        igor = ''
        length.times { igor += '*' }
        igorDescription.each do |part|
            igor[part[1], part[0].size] = part[0]
        end
        return igor
    end

    def run()
        @leftTags = Hash.new
        @rightTags = Hash.new
        @entries = Hash.new
        @entryCount = 0
        @input[:peptides].each do |path|
            File::open(path, 'r') do |f|
                id = nil
                entry = ''
                f.each_line do |line|
                    line.strip!
                    if line[0, 1] == '>'
                        handleEntry(id, entry) if id
                        id = line[1, line.size - 1]
                        entry = ''
                    else
                        entry += line
                    end
                end
                handleEntry(id, entry) if id
            end
        end
        puts "\rReading de novo peptides... #{@entryCount}."
        
        igorPeptides = Hash.new

        @leftTags.keys.sort.each do |length|
            overlap = Set.new(@leftTags[length].keys) & Set.new(@rightTags[length].keys)
            unless overlap.empty?
                overlap.each do |patch|
                    leftParts = Hash.new
                    @leftTags[length][patch].each do |key|
                        @entries[key].each do |entry|
                            leftParts[entry] = key if entry[0, length] == patch
                        end
                    end
                    rightParts = Hash.new
                    @rightTags[length][patch].each do |key|
                        @entries[key].each do |entry|
                            rightParts[entry] = key if entry[-length, length] == patch
                        end
                    end
                    leftParts.keys.each do |left|
                        rightParts.keys.each do |right|
                            # skip if from same scan! (or we would link AAABCDAAA with itself OMG!!)
                            next if leftParts[left] == rightParts[right]
                            igorDescription = Array.new
                            igorDescription << [right, 0]
                            igorDescription << [left, right.size - length]
                            igorPeptides[igorPeptideToString(igorDescription)] = igorDescription
                        end
                    end
                end
            end
        end

        while true do

            leftParts = Hash.new
            rightParts = Hash.new

            # collect left and right parts of every igor peptide

            igorPeptides.keys.each do |igorPeptide|
                igorDescription = igorPeptides[igorPeptide]
                left = igorDescription.first[0]
                right = igorDescription.last[0]
                leftParts[left] ||= Set.new
                leftParts[left] = igorPeptide
                rightParts[right] ||= Set.new
                rightParts[right] = igorPeptide
            end

            # determine left and right parts overlap
            
            foundSomething = false

            (Set.new(leftParts.keys) & Set.new(rightParts.keys)).each do |overlap|
                leftParts[overlap].each do |leftIgorPeptide|
                    rightParts[overlap].each do |rightIgorPeptide|
                        igorDescription = igorPeptides[rightIgorPeptide].dup
                        igorPeptides[leftIgorPeptide].each do |part|
                            adjustedPart = part.dup
                            adjustedPart[1] += igorPeptides[rightIgorPeptide].last[1]
                            igorDescription << adjustedPart
                        end
                        igorDescription.uniq!
                        igorString = igorPeptideToString(igorDescription)
                        unless igorPeptides.include?(igorString)
                            igorPeptides[igorString] = igorDescription
                            foundSomething = true
                        end
                    end
                end
            end
            
            break unless foundSomething
        end

        csvOut = nil
        csvOut = File::open(@output[:csvResults], 'w') if @output[:csvResults]
        fastaOut = nil
        fastaOut = File::open(@output[:fastaResults], 'w') if @output[:fastaResults]
        csvOut.puts "Peptide,Parts,Overlap min,Overlap mean,Overlap max,Peptide description" if csvOut
        igorPeptides.keys.sort { |a, b| igorPeptides[b].size <=> igorPeptides[a].size }.each do |key|
            pip = printIgorPeptide(igorPeptides[key])
            min, mean, max = igorPeptideOverlapStatistics(igorPeptides[key])
            csvOut.puts "#{key},#{igorPeptides[key].size},#{sprintf('%1.2f', min)},#{sprintf('%1.2f', mean)},#{sprintf('%1.2f', max)},#{pip}" if csvOut
            fastaOut.puts ">patchy_peptide_#{pip}\n#{key}" if fastaOut
        end
        csvOut.close() if csvOut
        fastaOut.close() if fastaOut
    end
end

lk_Object = PatchyPeptides.new
