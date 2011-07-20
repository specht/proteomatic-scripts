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
require './include/ruby/externaltools'
require './include/ruby/fasta'
require 'set'


class MatchPeptides < ProteomaticScript
    def run()
        # load peptides
        peptides = Set.new
        @input[:peptides].each do |path|
            File::open(path, 'r') do |f|
                f.each_line do |peptide|
                    peptide.strip!
                    next if peptide.empty?
                    peptides << peptide
                end
            end
        end
        puts "Matching #{peptides.size} peptides to #{@input[:databases].size} FASTA databases."
        peptidesPath = tempFilename('match-peptides-peptides-');
        File::open(peptidesPath, 'w') do |f|
            f.puts peptides.to_a.join("\n")
        end
        resultsPath = tempFilename('match-peptides-results-')
        results = Hash.new
        @input[:databases].each do |path|
            print "Matching to #{File::basename(path)}..."
            command = "\"#{ExternalTools::binaryPath('ptb.matchpeptides')}\" --output \"#{resultsPath}\" --peptideFiles \"#{peptidesPath}\" --modelFiles \"#{path}\""
            runCommand(command, true)
            results[path] = YAML::load_file(resultsPath)
            puts ' done.'
        end
        inputKeys = @input[:databases].collect { |x| File::basename(x) }
        if @output[:htmlResults]
            File::open(@output[:htmlResults], 'w') do |f|
                f.puts "<html>"
                f.puts "<head><title>Matched peptides</title>"
                f.puts DATA.read
                f.puts "</head>"
                f.puts "<body>"
                f.puts "<table>"
                f.puts "<thead>"
                f.puts "<tr>"
                f.puts "<th>Peptide</th>#{inputKeys.collect { |x| '<th>' + x + '</th>' }.join('')}"
                f.puts "</tr>"
                f.puts "</thead>"
                f.puts "<tbody>"
                peptides.to_a.sort.each do |peptide|
                    f.puts "<tr style='vertical-align: top;'>"
                    f.puts "<td>#{peptide}</td>"
                    @input[:databases].each do |path|
                        if results[path][peptide]
                            f.puts "<td><ul>#{results[path][peptide].keys.collect { |x| '<li>' + x + '</li>' }.join('')}</ul></td>"
                        else
                            f.puts "<td>&ndash;</td>"
                        end
                    end
                    f.puts "</tr>"
                end
                f.puts "</tbody>"
                f.puts "</table>"
                f.puts "</body>"
                f.puts "</html>"
            end
        end
        if @output[:csvResults]
            File::open(@output[:csvResults], 'w') do |f|
                f.puts "Peptide,Protein,Start,Length"
                peptides.to_a.sort.each do |peptide|
                    @input[:databases].each do |path|
                        if results[path][peptide]
                            results[path][peptide].keys.each do |protein|
                                results[path][peptide][protein].each do |x|
                                    f.puts "\"#{peptide}\",\"#{protein}\",#{x['start']},#{x['length']}"
                                end
                            end
                        end
                    end
                end
            end
        end
        if @output[:yamlResults]
            File::open(@output[:yamlResults], 'w') do |f|
                peptideList = []
                proteinList = []
                peptideIndex = {}
                proteinIndex = {}
                data = {}
                peptides.to_a.sort.each do |peptide|
                    peptideIndex[peptide] = peptideList.size
                    peptideList << peptide
                    @input[:databases].each do |path|
                        if results[path][peptide]
                            results[path][peptide].keys.each do |protein|
                                unless proteinIndex.include?(protein)
                                    proteinIndex[protein] = proteinList.size
                                    proteinList << protein
                                end
                                data[protein] ||= Set.new
                                data[protein] << peptide
                            end
                        end
                    end
                end
                result = {}
                result['peptides'] = peptideList
                result['proteins'] = proteinList
                result['peptidesForProtein'] = Hash.new
                proteinList.each do |protein|
                    result['peptidesForProtein'][proteinIndex[protein]] = []
                    data[protein].each do |peptide|
                        result['peptidesForProtein'][proteinIndex[protein]] << peptideIndex[peptide]
                    end
                end
                f.puts result.to_yaml
            end
        end
        if @output[:sequenceCoverage]
            File::open(@output[:sequenceCoverage], 'w') do |f|
                f.puts "<html>"
                f.puts "<head><title>Sequence coverage</title>"
                f.puts DATA.read
                f.puts "</head>"
                f.puts "<body>"
                @input[:databases].each do |key|
                    sequences = {}
                    fastaIterator(File::open(key)) do |id, seq|
                        sequences[id] = seq
                    end
                    f.puts "<h1>#{File::basename(key)}</h1>"
                    f.puts "<table>"
                    f.puts "<thead>"
                    f.puts "<tr style='vertical-align: top;'>"
                    f.puts "<th>Protein</th><th>Sequence</th><th>Coverage</th><th>Peptide count</th><th>Peptides</th>"
                    f.puts "</tr>"
                    f.puts "</thead>"
                    f.puts "<tbody>"
                    proteinHash = {}
                    # peptide:
                    #   protein A:
                    #     - left, right, start, length, proteinLength
                    #     - left, right, start, length, proteinLength
                    #   protein B:
                    #     - left, right, start, length, proteinLength
                    #     - left, right, start, length, proteinLength
                    results[key].each_pair do |peptide, x|
                        x.each_pair do |protein, matches|
                            proteinHash[protein] ||= Hash.new
                            proteinHash[protein][peptide] = matches
                        end
                    end
                    proteinCoverage = {}
                    proteinHash.keys.each do |protein|
                        proteinLength = proteinHash[protein].values.first.first['proteinLength']
                        covered = []
                        proteinLength.times { covered << false }
                        proteinHash[protein].each_pair do |peptide, infoList|
                            infoList.each do |info|
                                p = info['start']
                                info['length'].times do 
                                    covered[p] = true
                                    p += 1
                                end
                            end
                        end
                        proteinCoverage[protein] = covered.count(true).to_f / proteinLength
                    end
                    
                    proteinHash.keys.sort { |a, b| proteinCoverage[b] <=> proteinCoverage[a] }. each do |protein|
                        f.puts "<tr style='vertical-align: top;'>"
                        f.puts "<td>#{protein}</td>"
                        proteinLength = proteinHash[protein].values.first.first['proteinLength']
                        covered = []
                        proteinLength.times { covered << false }
                        proteinHash[protein].each_pair do |peptide, infoList|
                            infoList.each do |info|
                                p = info['start']
                                info['length'].times do 
                                    covered[p] = true
                                    p += 1
                                end
                            end
                        end
                        coverage = covered.count(true).to_f / proteinLength
                        printSequence = sequences[protein]
                        f.puts "<td style='font-family: monospace;'>"
                        i = 0
                        inSpan = false
                        while i < printSequence.size:
                            c = printSequence[i, 1]
                            if ((i > 0) && (covered[i] && !covered[i - 1])) || (i == 0 && covered[i])
                                f.print("<span style='background-color: #fce94f;'>") 
                                inSpan = true
                            end
                            f.print(c)
                            if ((i < proteinLength - 1) && (covered[i] && !covered[i + 1]))
                                f.print("</span>") 
                                inSpan = false
                            end
                            f.print("<br />") if (i + 1) % 70 == 0
                            i += 1
                        end
                        f.print("</span>") if inSpan
                        f.puts "</td>"
                        f.puts "<td>#{sprintf('%1.2f', coverage * 100)}%</td>"
                        f.puts "<td>#{proteinHash[protein].values.size}</td>"
                        f.puts "<td>#{proteinHash[protein].keys.join("<br />")}</td>"
                        f.puts "</tr>"
                    end
                    f.puts "</tbody>"
                    f.puts "</table>"
                end
                f.puts "</body>"
                f.puts "</html>"
            end
        end
    end
end

script = MatchPeptides.new

__END__
<style type='text/css'>
body {
    font-family: Verdana;
    font-size: 9pt;
}
th {
    text-align: left;
    border: 1px solid #000;
    background-color: #ddd;
    padding-left: 0.2em;
    padding-right: 0.2em;
}
td {
    text-align: left;
    border: 1px solid #000;
    padding-left: 0.2em;
    padding-right: 0.2em;
}
tr.protein {
    background-color: #eee;
}
table {
    border-collapse: collapse;
    font-size: 9pt;
}
.number {
    width: 3em;
    text-align: right;
}
.unmodpep {
    background-color: #fff;
}
.modpep {
    background-color: #fce94f;
}
.protein {
    background-color: #fff;
}

</style>
