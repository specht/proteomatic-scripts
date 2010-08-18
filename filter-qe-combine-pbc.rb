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
require 'include/ruby/ext/fastercsv'
require 'include/ruby/misc'
require 'set'
require 'yaml'


class CombinePbc < ProteomaticScript
    def run()
        proteinHash = Hash.new
        peptideHash = Hash.new
        pbcHash = Hash.new
        hasProteins = true
        @input[:quantitationEvents].each do |path|
            File::open(path, 'r') do |f|
                header = mapCsvHeader(f.readline)
                hasProteins = false unless header.include?('protein')
                f.each_line do |line|
                    lineArray = line.parse_csv()
                    lineHash = Hash.new
                    header.each_pair do |key, index|
                        lineHash[key] = lineArray[index]
                    end
                    pbcKey = "#{lineHash['peptide']}/#{lineHash['filename']}/#{lineHash['charge']}"
                    pbcHash[pbcKey] ||= {
                        :amounts => Array.new, 
                        :peptide => lineHash['peptide'],
                        :band => lineHash['filename'],
                        :charge => lineHash['charge'].to_i,
                        :protein => lineHash['protein']
                    }
                    pbcHash[pbcKey][:amounts] << [lineHash['amountlight'].to_f, lineHash['amountheavy'].to_f]
                    if (lineHash.include?('protein'))
                        protein = lineHash['protein']
                        proteinHash[protein] ||= Set.new
                        proteinHash[protein] << pbcKey
                    end
                    peptide = lineHash['peptide']
                    peptideHash[peptide] ||= Set.new
                    peptideHash[peptide] << pbcKey
                end
            end
        end
        
        # do calculations
        pbcHash.keys.sort.each do |pbcKey|
            amountLight = 0.0
            amountHeavy = 0.0
            ratios = Array.new
            hasSingleStateEvents = false
            hasBothStateEvents = false
            pbcHash[pbcKey][:amounts].each do |x| 
                amountLight += x[0]
                amountHeavy += x[1]
                ratios << x[0] / x[1]
                hasSingleStateEvents = true if (x[0] == 0.0) || (x[1] == 0.0)
                hasBothStateEvents = true if (x[0] > 0.0) && (x[1] > 0.0)
            end
            # reject single state events if there are 'proper' ratios
            if (hasSingleStateEvents && hasBothStateEvents)
                ratios.reject! do |x|
                    (x == 0.0) || (x == 1.0 / 0)
                end
            end
            ratioMean, ratioSD = meanAndSd(ratios)
            ratioRSD = nil
            unless ratioMean == nil
                ratioRSD = ratioSD / ratioMean if ratioSD && ratioMean
            end
            pbcHash[pbcKey][:amountLight] = amountLight
            pbcHash[pbcKey][:amountHeavy] = amountHeavy
            pbcHash[pbcKey][:ratio] = amountLight / amountHeavy
            pbcHash[pbcKey][:scanCount] = ratios.size
            pbcHash[pbcKey][:scanRatioMean] = ratioMean
            pbcHash[pbcKey][:scanRatioSD] = ratioSD
            pbcHash[pbcKey][:scanRatioRSD] = ratioRSD
        end
        
        # write output files
        if @output[:pbcResults]
            File::open(@output[:pbcResults], 'w') do |lk_Out|
                lk_Out.print "Protein," if hasProteins
                lk_Out.puts "Peptide,Band,Charge,Scan count,Amount light,Amount heavy,PBC ratio,Scan ratio mean,Scan ratio SD,Scan ratio RSD"
                pbcHash.keys.sort do |a, b|
                    hasProteins ? 
                        ((pbcHash[a][:protein] == pbcHash[b][:protein]) ?
                         a <=> b :
                         pbcHash[a][:protein] <=> pbcHash[b][:protein]) : 
                        a <=> b
                end.each do |pbcKey|
                    lk_Out.print "\"#{pbcHash[pbcKey][:protein]}\"," if hasProteins
                    lk_Out.puts "#{pbcHash[pbcKey][:peptide]},\"#{pbcHash[pbcKey][:band]}\",#{pbcHash[pbcKey][:charge]},#{pbcHash[pbcKey][:scanCount]},#{pbcHash[pbcKey][:amountLight]},#{pbcHash[pbcKey][:amountHeavy]},#{pbcHash[pbcKey][:ratio]},#{pbcHash[pbcKey][:scanRatioMean]},#{pbcHash[pbcKey][:scanRatioSD]},#{pbcHash[pbcKey][:scanRatioRSD]}"
                end
            end
        end
        if @output[:proteinResults]
            File::open(@output[:proteinResults], 'w') do |lk_Out|
                lk_Out.puts "Protein,PBC count,Scan count,Ratio mean,Ratio SD,Ratio RSD"
                proteinHash.keys.sort.each do |protein|
                    scanCount = 0
                    proteinHash[protein].each do |pbcKey|
                        scanCount += pbcHash[pbcKey][:scanCount]
                    end
                    pbcCount = proteinHash[protein].size
                    ratioMean = nil
                    ratioSD = nil
                    ratioRSD = nil
                    if pbcCount == 1
                        # if PBC count is 1, use the individual scan ratios
                        ratioMean = pbcHash[proteinHash[protein].to_a.first][:scanRatioMean]
                        ratioSD = pbcHash[proteinHash[protein].to_a.first][:scanRatioSD]
                        ratioRSD = pbcHash[proteinHash[protein].to_a.first][:scanRatioRSD]
                    else
                        # if PBC count is greater than 1, use PBC ratios
                        ratios = Array.new
                        hasSingleStateEvents = false
                        hasBothStateEvents = false
                        proteinHash[protein].each do |pbcKey|
                            x = pbcHash[pbcKey][:ratio]
                            ratios << x
                            hasSingleStateEvents = true if (x == 0.0) || (x == 1.0 / 0)
                            hasBothStateEvents = true if (x != 0.0) && (x != 1.0 / 0)
                        end
                        # reject single state events if there are 'proper' ratios
                        if (hasSingleStateEvents && hasBothStateEvents)
                            ratios.reject! do |x|
                                (x == 0.0) || (x == 1.0 / 0)
                            end
                            # update PBC count
                            pbcCount = ratios.size
                        end
                        ratioMean, ratioSD = meanAndSd(ratios)
                        ratioRSD = nil
                        unless ratioMean == nil
                            ratioRSD = ratioSD / ratioMean if ratioSD && ratioMean
                        end
                        if (pbcCount == 1)
                            # if the PBC count has gone down to 1, use scan results
                            ratioMean = pbcHash[proteinHash[protein].to_a.first][:scanRatioMean]
                            ratioSD = pbcHash[proteinHash[protein].to_a.first][:scanRatioSD]
                            ratioRSD = pbcHash[proteinHash[protein].to_a.first][:scanRatioRSD]
                        end
                    end
                    lk_Out.puts "\"#{protein}\",#{pbcCount},#{scanCount},#{ratioMean},#{ratioSD},#{ratioRSD}"
                end
            end
        end
        if @output[:peptideResults]
            File::open(@output[:peptideResults], 'w') do |lk_Out|
                lk_Out.puts "Peptide,PBC count,Scan count,Ratio mean,Ratio SD,Ratio RSD"
                peptideHash.keys.sort.each do |peptide|
                    scanCount = 0
                    peptideHash[peptide].each do |pbcKey|
                        scanCount += pbcHash[pbcKey][:scanCount]
                    end
                    pbcCount = peptideHash[peptide].size
                    ratioMean = nil
                    ratioSD = nil
                    ratioRSD = nil
                    if pbcCount == 1
                        # if PBC count is 1, use the individual scan ratios
                        ratioMean = pbcHash[peptideHash[peptide].to_a.first][:scanRatioMean]
                        ratioSD = pbcHash[peptideHash[peptide].to_a.first][:scanRatioSD]
                        ratioRSD = pbcHash[peptideHash[peptide].to_a.first][:scanRatioRSD]
                    else
                        # if PBC count is greater than 1, use PBC ratios
                        ratios = Array.new
                        hasSingleStateEvents = false
                        hasBothStateEvents = false
                        peptideHash[peptide].each do |pbcKey|
                            x = pbcHash[pbcKey][:ratio]
                            ratios << x
                            hasSingleStateEvents = true if (x == 0.0) || (x == 1.0 / 0)
                            hasBothStateEvents = true if (x != 0.0) && (x != 1.0 / 0)
                        end
                        # reject single state events if there are 'proper' ratios
                        if (hasSingleStateEvents && hasBothStateEvents)
                            ratios.reject! do |x|
                                (x == 0.0) || (x == 1.0 / 0)
                            end
                            # update PBC count
                            pbcCount = ratios.size
                        end
                        ratioMean, ratioSD = meanAndSd(ratios)
                        ratioRSD = nil
                        unless ratioMean == nil
                            ratioRSD = ratioSD / ratioMean if ratioSD && ratioMean
                        end
                        if (pbcCount == 1)
                            # if the PBC count has gone down to 1, use scan results
                            ratioMean = pbcHash[peptideHash[peptide].to_a.first][:scanRatioMean]
                            ratioSD = pbcHash[peptideHash[peptide].to_a.first][:scanRatioSD]
                            ratioRSD = pbcHash[peptideHash[peptide].to_a.first][:scanRatioRSD]
                        end
                    end
                    lk_Out.puts "\"#{peptide}\",#{pbcCount},#{scanCount},#{ratioMean},#{ratioSD},#{ratioRSD}"
                end
            end
        end
    end
end

lk_Object = CombinePbc.new
