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
require 'yaml'
require 'set'


class CheckMod < ProteomaticScript
    def run()
        peptides = @param[:peptides].split(/[\s,]+/)
        peptides.collect! { |x| x.strip.upcase }
        peptides.reject! { |x| x.empty? }
        peptides.sort!
        peptides.uniq!
        
        modPeptides = Set.new
        
        peptides.each do |peptide|
            # create all possible modification states
            places = []
            (0...peptide.size).each do |i|
                aa = peptide[i, 1]
                if 'STY'.include?(aa)
                    places << i
                end
            end
            possibilities = 1 << places.size
            (0...possibilities).each do |pattern|
                modPeptide = peptide.dup
                (0...places.size).each do |i|
                    if ((pattern >> i) & 1) != 0
                        modPeptide[places[i], 1] = modPeptide[places[i], 1].downcase
                    end
                end
                modPeptides << modPeptide
            end
        end

        ids = @param[:ids].split(/[\s,]+/)
        ids.collect! { |x| x.strip }
        ids.reject! { |x| x.empty? }
        ids.sort!
        ids.uniq!
        
        puts "Matching #{peptides.size} peptide#{peptides.size == 1 ? '' : 's'} with a total of #{modPeptides.size} modification states against #{ids.size} #{ids.size == 1 ? 'spectrum' : 'spectra'}."
        
        # check if there are spectra files that are not dta or mgf
        lk_PreparedSpectraFiles = Array.new
        lk_XmlFiles = Array.new
        @input[:spectra].each do |ls_Path|
            if @inputFormat[ls_Path] == 'mgf'
                # it's MGF, use it directly
                lk_PreparedSpectraFiles.push(ls_Path)
            else
                # it's something else, convert it first
                lk_XmlFiles.push("\"" + ls_Path + "\"") 
            end
        end
        
        @ms_TempPath = tempFilename('checkmod')
        FileUtils::mkpath(@ms_TempPath)
        
        unless (lk_XmlFiles.empty?)
            # convert spectra to MGF
            puts 'Converting XML spectra to MGF format...'
            ls_Command = "\"#{ExternalTools::binaryPath('ptb.xml2mgf')}\" -i \"#{ids.join(' ')}\" -o \"#{@ms_TempPath}/mgf-in\" #{lk_XmlFiles.join(' ')}"
            runCommand(ls_Command)
            
            lk_PreparedSpectraFiles = lk_PreparedSpectraFiles + Dir[@ms_TempPath + '/mgf-in*']
        end
        
        # read input MGF files, extract spectra and do the job
        
        scans = Hash.new
        
        lk_PreparedSpectraFiles.each do |path|
            peaks = Array.new
            charge = nil
            scanid = nil
            pepmass = nil
            File::open(path, 'r') do |f|
                inScan = false
                f.each_line do |line|
                    line.strip!
                    next if line.empty?
                    if line == 'BEGIN IONS'
                        inScan = true
                        peaks = Array.new
                        charge = nil
                        scanid = nil
                        pepmass = nil
                    elsif line == 'END IONS'
                        scans[scanid] = {:charge => charge, :precursor => pepmass, :peaks => peaks}
                        inScan = false
                    elsif line =~ /[A-Z]+=.+/
                        # property
                        lineArray = line.split('=')
                        key = lineArray[0].upcase
                        value = lineArray[1]
                        if key == 'CHARGE'
                            charge = value.to_i
                        elsif key == 'TITLE'
                            scanid = value.split('.')[-2]
                        elsif key == 'PEPMASS'
                            pepmass = value.to_f
                        end
                    else
                        # m/z intensity pair
                        lineArray = line.split(/\s/)
                        mz = lineArray[0].to_f
                        intensity = lineArray[1].to_f
                        peaks << [mz, intensity]
                    end
                end
            end
        end

        iterationCount = modPeptides.size * ids.size
        i = 0
        results = Array.new
        modPeptides.each do |modPeptide|
            ids.each do |id|
                print "\rMatching... #{sprintf('%d', i * 100 / iterationCount)}% done."
                i += 1
                score = calculateScore(scans[id], modPeptide)
                if score[:precursorIonAccuracy] <= @param[:precursorIonMassAccuracy]
                    results << {:id => id, :modPeptide => modPeptide, :score => score[:score], :precursorIonAccuracy => score[:precursorIonAccuracy]}
                end
            end
        end
        print "\rMatching... 100% done."
        puts 
        
        results.sort! do |a, b|
            if a[:id] == b[:id]
                b[:score] <=> a[:score]
            else
                a[:id] <=> b[:id]
            end
        end
        oldId = nil
        results.each do |x|
            if x[:id] != oldId
                puts
                puts "Scan ##{x[:id]}:"
                oldId = x[:id]
            end
            puts "#{sprintf('%9.4f', x[:score])}, #{x[:modPeptide]} (#{sprintf('%1.2f', x[:precursorIonAccuracy])} ppm)"
        end
        puts
        
        FileUtils::rm_rf(@ms_TempPath)
    end        
    
    def calculateScore(scan, peptide)
        lk_Masses = {'G' => 57.021464, 'A' => 71.037114, 'S' => 87.032029,
            'P' => 97.052764, 'V' => 99.068414, 'T' => 101.04768, 'C' => 103.00919,
            'L' => 113.08406, 'I' => 113.08406, 'N' => 114.04293, 'D' => 115.02694,
            'Q' => 128.05858, 'K' => 128.09496, 'E' => 129.04259, 'M' => 131.04048,
            'H' => 137.05891, 'F' => 147.06841, 'R' => 156.10111, 'Y' => 163.06333,
            'W' => 186.07931, '$' => 0.0, 'X' => 0.0}
        ld_Water = 18.01057
        # UNSURE ABOUT THIS VALUE BUT OK WITH BIANCAS EXAMPLES, should be 1.0078250
        ld_Hydrogen = 1.0073250
        ld_Phosphorylation = 79.966330408
        
        ions = Hash.new

        # collect b ions
        fragmentMass = 0.0
        (0...peptide.size).each do |i|
            aa = peptide[i, 1]
            fragmentMass += lk_Masses[aa.upcase]
            if aa =~ /[a-z]/
                fragmentMass += ld_Phosphorylation
            end
            ions[{:origin => "b#{i + 1}", :mods => Set.new, :score => 1.0}] = fragmentMass
        end
        
        # collect y ions
        fragmentMass = ld_Water
        (0...peptide.size).each do |i|
            aa = peptide[peptide.size - i - 1, 1]
            fragmentMass += lk_Masses[aa.upcase]
            if aa =~ /[a-z]/
                fragmentMass += ld_Phosphorylation
            end
            ions[{:origin => "y#{i + 1}", :mods => Set.new, :score => 1.0}] = fragmentMass
        end
        

        # add water loss
        newIons = Hash.new
        (0..5).each do |i|
            ions.each do |key, mass|
                newKey = YAML::load(key.to_yaml)
                newKey[:mods] << "-#{i}H20" if i > 0
                newKey[:score] *= 0.5 ** i
                newIons[newKey] = mass - ld_Water * i
            end
        end
        ions = YAML::load(newIons.to_yaml)
        
        # add PA loss
        newIons = Hash.new
        (0..1).each do |i|
            ions.each do |key, mass|
                newKey = YAML::load(key.to_yaml)
                newKey[:mods] << "-H3PO4" if i > 0
                newKey[:score] *= 0.5 if i > 0
                newIons[newKey] = mass - (ld_Phosphorylation + ld_Water) * i
            end
        end
        ions = YAML::load(newIons.to_yaml)
        
        # add charge states
        oldIons = ions.dup
        ions = Hash.new
        (1..scan[:charge]).each do |i|
            oldIons.each do |key, mass|
                newKey = key.dup
                newKey[:charge] = i
                ions[newKey] = (mass + i * ld_Hydrogen) / i
            end
        end
        
#         ions.keys.each do |key|
#             puts "#{key[:origin]}#{key[:mods].to_a.sort.join(' ')} (#{key[:charge]}+): #{ions[key]} / #{key[:score]}"
#         end
#         puts peaks.to_yaml
        peaks = scan[:peaks].dup
        minMz = peaks.collect { |x| x.first}.min
        maxMz = peaks.collect { |x| x.first}.max
        maxIntensity = peaks.collect { |x| x[1]}.max
#         puts "m/z range is #{minMz} - #{maxMz}, max intensity is #{maxIntensity}"
        
#         puts "There are #{peaks.size} peaks in the scan."
        peaks.reject! do |x|
            x[1] / maxIntensity < @param[:noiseFilter] / 100.0
        end
#         puts "After filtering out the low peaks, there are #{peaks.size} peaks left."
        
        errors = Array.new
        intensities = Array.new
        ids = Array.new
        scores = Array.new
        
        ions.each do |key, mz|
            next unless (minMz..maxMz).include?(mz)
            matches = Array.new
            # :TODO: do a binary search here, it's faster
            peaks.each do |peak|
                error = ((mz - peak[0]) / mz * 1000000.0).abs
                matches << peak if error <= @param[:productIonMassAccuracy]
            end
            next if matches.empty?
            # select higher peak if multiple matches
            if matches.size > 1
                matches.sort! { |x, y| y[1] <=> x[1] }
            end
            match = matches.first
            error = ((mz - match[0]) / mz * 1000000.0).abs
            errors << error
            intensities << match[1] / maxIntensity
            ids << "#{key[:origin]}#{key[:mods].to_a.sort.join('')} (#{key[:charge]}+)"
            scores << key[:score] * (match[1] / maxIntensity)
        end
        
#         puts "Matching peaks: #{errors.size}."
        averageIntensity = intensities.inject { |x, y| x + y } / intensities.size
#         puts "Average intensity is #{averageIntensity * 100.0}."
        medianIntensity = intensities[intensities.size / 2]
#         puts "Median intensity is #{medianIntensity * 100.0}."
        averageError = errors.inject { |x, y| x + y } / errors.size
#         puts "Average error is #{averageError} ppm."
        medianError = errors[errors.size / 2]
#         puts "Median error is #{medianError} ppm."
        averageScore = scores.inject { |x, y| x + y }
#         puts "Score is #{averageScore}."
        precursorMz = scan[:precursor]
        theoMz = ld_Water
        (0...peptide.size).each do |i|
            aa = peptide[i, 1]
            theoMz += lk_Masses[aa.upcase]
            if aa =~ /[a-z]/
                theoMz += ld_Phosphorylation
            end
        end
        theoMz = (theoMz + (ld_Hydrogen * scan[:charge])) / scan[:charge]
        precursorIonAccuracy = ((theoMz - precursorMz) / theoMz).abs() * 1000000.0
        
        return {:score => averageScore, :precursorIonAccuracy => precursorIonAccuracy}
    end
end

lk_Object = CheckMod.new
