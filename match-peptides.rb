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
    end
end

lk_Object = MatchPeptides.new

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
