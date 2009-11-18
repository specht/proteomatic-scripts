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

require 'include/proteomatic'
require 'include/evaluate-omssa-helper'
require 'include/ext/fastercsv'
require 'include/misc'
require 'set'
require 'yaml'

class WriteBlastReport < ProteomaticScript
    
    $gk_Gradient = {'burn' => [
        [0.0, '#ffffff'],
        [0.2, '#fce94f'],
        [0.4, '#fcaf3e'],
        [0.7, '#a40000'],
        [1.0, '#000000']
        ],
        'green' => [[0.0, '#ffffff'], [1.0, '#4e9a06']]
    }
        
        
    def mix(a, b, amount)
        rA = Integer('0x' + a[1, 2]).to_f / 255.0
        gA = Integer('0x' + a[3, 2]).to_f / 255.0
        bA = Integer('0x' + a[5, 2]).to_f / 255.0
        rB = Integer('0x' + b[1, 2]).to_f / 255.0
        gB = Integer('0x' + b[3, 2]).to_f / 255.0
        bB = Integer('0x' + b[5, 2]).to_f / 255.0
        rC = rB * amount + rA * (1.0 - amount)
        gC = gB * amount + gA * (1.0 - amount)
        bC = bB * amount + bA * (1.0 - amount)
        result = sprintf('#%02x%02x%02x', (rC * 255.0).to_i, (gC * 255.0).to_i, (bC * 255.0).to_i)
        return result
    end
        
        
    def gradient(x, key = 'burn')
        x = 0.0 if x < 0.0
        x = 1.0 if x > 1.0
        i = 0
        while (i < $gk_Gradient[key].size - 2 && $gk_Gradient[key][i + 1][0] < x)
            i += 1
        end
        colorA = $gk_Gradient[key][i][1]
        colorB = $gk_Gradient[key][i + 1][1]
        return mix(colorA, colorB, (x - $gk_Gradient[key][i][0]) / ($gk_Gradient[key][i + 1][0] - $gk_Gradient[key][i][0]))
    end
        

    def run()
        if @output[:htmlReport]
            File::open(@output[:htmlReport], 'w') do |lk_Out|
                lk_Out.puts <<EOF
                <style type='text/css'>
                table {
                    border-width: 1px 1px 1px 1px;
                    border-spacing: 2px;
                    border-style: outset outset outset outset;
                    border-color: gray gray gray gray;
                    border-collapse: collapse;
                    background-color: white;
                }
                table th {
                    border-width: 1px 1px 1px 1px;
                    padding: 1px 3px 1px 3px;
                    border-style: inset inset inset inset;
                    border-color: gray gray gray gray;
                    background-color: white;
                }
                table td {
                    border-width: 1px 1px 1px 1px;
                    padding: 1px 3px 1px 3px;
                    border-style: inset inset inset inset;
                    border-color: gray gray gray gray;
                    background-color: white;
                }
                </style>
EOF

                @input[:resultFile].sort.each do |path|
                    hits = Hash.new
                    
                    run = File::basename(path).split('-').first
                    
                    File::open(path, 'r') do |f|
                        header = mapCsvHeader(f.readline)
                        f.each_line do |line|
                            lineArray = line.parse_csv()
                            query = lineArray[header['querydef']]
                            hit = lineArray[header['hitdef']]
                            score = lineArray[header['hspevalue']].to_f
                            hits[query] ||= Array.new
                            hits[query] << {:score => score, :hit => hit}
                        end
                    end

                    hits.keys.each do |query|
                        hits[query].sort! { |a, b| a[:score] <=> b[:score] }
                    end

                    lk_Out.puts "<h3>#{File::basename(path)}</h3>"

                    lk_Out.puts "<table style='font-size: 8pt; font-family: monospace; border-style: solid; border-collapse: collapse; '>"
                    lk_Out.puts "<tr>"
                    lk_Out.puts "<th style='text-align: left'>Score</th><th style='text-align: left'>Query</th><th style='text-align: left'>Tags</th>"
                    lk_Out.puts "</tr>"
                    hits.keys.sort { |a, b| hits[a].first[:score] <=> hits[b].first[:score] }.each do |query|
                        words = Hash.new
                        wordIndex = Hash.new
                        maxWordCount = 0
                        hits[query].each do |hit|
                            hitLine = hit[:hit].upcase
                            hitLine.gsub!(/\[[^\]]+\]/, '')
                            hitLine.gsub!('FULL=', '')
                            hitLine.gsub!('SHORT=', '')
                            hitLine.gsub!('RECNAME:', '')
                            parts = hitLine.split('&GT;').collect { |x| x.strip }
                            parts.each do |part|
                                partParts = part.split(/\s/)
                                partParts.each do |partPart|
                                    next if partPart.include?('|')
                                    while partPart.size > 0 && !partPart[0, 1].index(/[A-Z0-9]/)
                                        partPart = partPart[1, partPart.size - 1]
                                    end
                                    while partPart.size > 0 && !partPart[-1, 1].index(/[A-Z0-9]/)
                                        partPart = partPart[0, partPart.size - 1]
                                    end
                                    unless partPart.empty?
                                        words[partPart] ||= 0
                                        words[partPart] += 1
                                        maxWordCount = words[partPart] if words[partPart] > maxWordCount
                                        wordIndex[partPart] ||= hitLine.index(partPart)
                                    end
                                end
                            end
                        end
                        lk_Out.puts "<tr>"
                        lk_Out.puts "<td>#{sprintf('%1.4f', hits[query].first[:score])}</td>"
                        lk_Out.print '<td>'
                        #p = patchyPeptides[query.sub('patchy_peptide_', '')]
                        p = query.dup
                        if (p.index('patchy_peptide_') == 0)
                            p.gsub!('patchy_peptide_', '')
                            depth = 0
                            gotSpan = false
                            (0...p.size).each do |i|
                                if p[i, 1] == '['
                                    depth += 1
                                    lk_Out.print "</span>" if gotSpan
                                    lk_Out.print "<span style='background-color: #{gradient(depth.to_f / 4.0, 'green')}'>"
                                    gotSpan = true
                                elsif p[i, 1] == ']'
                                    depth -= 1
                                    lk_Out.print "</span>"
                                    lk_Out.print "<span style='background-color: #{gradient(depth.to_f / 4.0, 'green')}'>"
                                else
                                    lk_Out.print p[i, 1]
                                end
                            end
                            lk_Out.print "</span>"
                        else
                            lk_Out.print(p)
                        end
                        lk_Out.puts '</td>'
                        lk_Out.puts "<td>"
                        words.keys.sort { |a, b| wordIndex[a] <=> wordIndex[b] }.each do |word|
                            wordRatio = words[word].to_f / maxWordCount
                            if wordRatio >= @param[:tagCropThreshold] / 100.0
                                lk_Out.print "<span style='background-color: #{gradient((wordRatio) * 0.6)};'>#{word}</span> "
                            end
                        end
                        lk_Out.puts "<br />"
                        lk_Out.puts "</td></td>"
                    end

                    lk_Out.puts "</table>"
                end
            end
        end
    end
end

lk_Object = WriteBlastReport.new
