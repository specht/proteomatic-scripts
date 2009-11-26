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

require 'include/ruby/proteomatic'
require 'yaml'
require 'set'


class IsotopeEnvelope < ProteomaticScript
    
    def loadData()
        @isotopes = Hash.new

        File::open('include/proteomics-knowledge-base/isotopes.csv', 'r') do |f|
            header = mapCsvHeader(f.readline)
            f.each_line do |line|
                lineArray = line.parse_csv()
                element = lineArray[header['element']]
                isotope = lineArray[header['isotope']].to_i
                mass = lineArray[header['monoisotopicmass']].to_f
                abundance = lineArray[header['naturalabundance']].to_f
                if (@param[:label] == 'N15')
                    if element == 'N'
                        if isotope == 15
                            abundance = @param[:labelingEfficiency] / 100.0
                        else
                            abundance = 1.0 - @param[:labelingEfficiency] / 100.0
                        end
                    end
                end
                @isotopes[element] ||= Array.new
                lastAccumulatedAbundance = 0
                lastAccumulatedAbundance = @isotopes[element].last[:accumulatedAbundance] unless @isotopes[element].empty?
                @isotopes[element] ||= Array.new
                @isotopes[element] << {:isotope => isotope, :mass => mass, :accumulatedAbundance => lastAccumulatedAbundance + abundance }
            end
        end

        @aminoAcidComposition = Hash.new

        File::open('include/proteomics-knowledge-base/amino-acids.csv', 'r') do |f|
            header = mapCsvHeader(f.readline)
            f.each_line do |line|
                lineArray = line.parse_csv()
                aaLetter = lineArray[header['singlelettercode']]
                composition = lineArray[header['composition']]
                next if (!composition) || composition.empty?
                result = Hash.new
                i = 0
                while (i < composition.size)
                    letter = composition[i, 1]
                    i += 1
                    numberString = ''
                    while (i < composition.size && composition[i, 1] =~ /\d/)
                        numberString += composition[i, 1]
                        i += 1
                    end
                    numberString = '1' if numberString.empty?
                    count = numberString.to_i
                    result[letter] = count
                end
                @aminoAcidComposition[aaLetter] = result
            end
        end
    end
    
    
    def pickAtom(element, random = true)
        r = rand()
        i = 0
        if random
            while @isotopes[element][i][:accumulatedAbundance] < r
                i += 1
            end
        else
            i = 1 if @param[:label] == 'N15' && element == 'N'
        end
        return [@isotopes[element][i][:isotope], @isotopes[element][i][:mass]]
    end


    def pickPeptide(peptide, random = true)
        mass = [0, 0.0]
        atom = pickAtom('H', random)
        (0...atom.size).each { |i| mass[i] += atom[i] }
        atom = pickAtom('H', random)
        (0...atom.size).each { |i| mass[i] += atom[i] }
        atom = pickAtom('O', random)
        (0...atom.size).each { |i| mass[i] += atom[i] }
        (0...peptide.size).each do |i|
            aa = peptide[i, 1]
            @aminoAcidComposition[aa].keys.each do |element|
                @aminoAcidComposition[aa][element].times do
                    atom = pickAtom(element, random)
                    (0...atom.size).each { |i| mass[i] += atom[i] }
                end
            end
        end
        return mass
    end
    
    
	def run()
        loadData()

        lowest = pickPeptide(@param[:peptide], false)
        histogram = Hash.new
        minMass = Hash.new
        maxMass = Hash.new
        @param[:count].times do 
            pick = pickPeptide(@param[:peptide])
            pick[0] -= lowest[0]
            histogram[pick[0]] ||= 0
            histogram[pick[0]] += 1
            minMass[pick[0]] ||= pick[1]
            minMass[pick[0]] = pick[1] if pick[1] < minMass[pick[0]]
            maxMass[pick[0]] ||= pick[1]
            maxMass[pick[0]] = pick[1] if pick[1] > maxMass[pick[0]]
        end
        max = 0.0
        histogram.values.each { |x| max = x if x > max }
        histogram.keys.sort.each do |isotope|
            m0 = minMass[isotope]
            m1 = maxMass[isotope]
            average = (m0 + m1) * 0.5
            error = (m0 - average).abs() / average * 1000000.0
            puts "A#{@param[:label] != 'none' ? '*' : ''}#{sprintf('%+d', isotope)}: #{sprintf('%1.6f', histogram[isotope].to_f / max)} (#{sprintf('%1.2f', error)} ppm)"
        end
	end
end

lk_Object = IsotopeEnvelope.new
