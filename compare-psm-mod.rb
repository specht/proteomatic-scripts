#! /usr/bin/env ruby
# Copyright (c) 2009-2010 Michael Specht
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


def meanAndStandardDeviation(ak_Values)
    ld_Mean = 0.0
    ld_Sd = 0.0
    ak_Values.each { |x| ld_Mean += x }
    ld_Mean /= ak_Values.size
    ak_Values.each { |x| ld_Sd += ((x - ld_Mean) ** 2.0) }
    ld_Sd /= ak_Values.size
    ld_Sd = Math.sqrt(ld_Sd)
    return ld_Mean, ld_Sd
end

def unionAndIntersection(sets)
    union = Set.new()
    intersection = nil
    sets.each do |s|
        union |= s
        intersection ||= s
        intersection &= s
    end
    return union, intersection
end


class ComparePsmMod < ProteomaticScript
    
    # removes leading zeroes from scan counts, like so:
    # 'JP_conF_7-24_E1_271009.0889.0889.3' => 'JP_conF_7-24_E1_271009.889.889.3'
    def sanitizeScanId(id)
        parts = id.split('.')
        result = id
        if parts.size >= 4
            parts[-2] = parts[-2].to_i.to_s
            parts[-3] = parts[-3].to_i.to_s
            result = parts.join('.')
        end
        return result
    end
    
    def run()
        lk_Files = @input[:sequestResults] + @input[:omssaResults]
        lk_Ids = lk_Files.collect { |x| File::basename(x).sub('.csv', '') }.sort
        lk_ProteinsForId = Hash.new
        fullProteinForProteinId = Hash.new

        # lk_AllResults:
        #   protein 1:
        #     PEPTiDE: 
        #       omssa-file: [scan1, scan2]
        #       sequest-file: [scan2, scan3]
        lk_AllResults = Hash.new
        
        # parse OMSSA CSV files
        @input[:omssaResults].each do |ls_Path|
            print "#{File::basename(ls_Path)}: "
            ls_Id = File::basename(ls_Path).sub('.csv', '')
            lk_Results = loadPsm(ls_Path, :silent => true)
            #puts lk_Results.to_yaml
            # lk_Results[:proteins] => {'protein' => ['pep1', 'pep2']}
            # lk_Results[:peptideHash] => {'peptide' => {:scans => [scans...]}}
            lk_ProteinsForId[ls_Id] = Set.new()
            puts "#{lk_Results[:proteins].size} proteins."
            lk_Results[:proteins].keys.each do |ls_OriginalProtein|
                ls_Protein = ls_OriginalProtein.dup
                ls_Protein = ls_Protein.split(/\s/).first if @param[:useProteinIds]
                fullProteinForProteinId[ls_Protein] ||= Set.new
                fullProteinForProteinId[ls_Protein] << ls_OriginalProtein
                lk_ProteinsForId[ls_Id] << ls_Protein
                lk_Results[:proteins][ls_OriginalProtein].each do |ls_Peptide|
                    lk_Results[:peptideHash][ls_Peptide][:scans].each do |ls_Scan|
                        ls_Scan = sanitizeScanId(ls_Scan)
                        # initialize ls_ModPeptide with clean unmodified peptide
                        ls_ModPeptide = ls_Peptide
                        # if there's a modification, update ls_ModPeptide
                        unless lk_Results[:scanHash][ls_Scan][:mods].empty?
                            ls_ModPeptide = Set.new(lk_Results[:scanHash][ls_Scan][:mods].collect { |x| x[:peptide] }).to_a.sort.join(' / ')
                        end
                        lk_AllResults[ls_Protein] ||= Hash.new
                        lk_AllResults[ls_Protein][ls_ModPeptide] ||= Hash.new
                        lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id] ||= Set.new()
                        lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id] << ls_Scan
                    end
                end
            end
        end

        lk_ScanHash = Hash.new
        # parse SEQUEST CSV files, collect all unambiguous scans
        @input[:sequestResults].each do |ls_Path|
            print "#{File::basename(ls_Path)}: "
            if @param[:sequestFormat] == 'srf'
                # SRF exported format
                lk_ThisProteins = Set.new
                ls_Id = File::basename(ls_Path).sub('.csv', '')
                ls_Protein = nil
                lk_ForbiddenScanIds = Set.new
                File::open(ls_Path, 'r') do |lk_File|
                    lk_File.each_line do |ls_Line|
                        lk_Line = ls_Line.parse_csv
                        if (lk_Line[0] && (!lk_Line[0].empty?))
                            # here comes a protein
                            ls_Protein = lk_Line[1].strip
                            ls_OriginalProtein = ls_Protein.dup
                            ls_Protein = ls_Protein.split(/\s/).first if @param[:useProteinIds]
                            fullProteinForProteinId[ls_Protein] ||= Set.new
                            fullProteinForProteinId[ls_Protein] << ls_OriginalProtein
                            lk_ThisProteins << ls_Protein
                            next
                        end
                        if (ls_Protein && lk_Line[2])
                            # here comes a peptide
                            ls_ScanId = File::basename(ls_Path) + '.' + lk_Line[1]
                            ls_ScanId = sanitizeScanId(ls_ScanId)
                            next if lk_ForbiddenScanIds.include?(ls_ScanId)
                            if lk_Line[2].split('.').size != 3
                                puts "Error: Expecting K.PEPTIDER.A style peptides in SEQUEST results."
                                exit 1
                            end
                            ls_Peptide = lk_Line[2].split('.')[1].strip
                            ls_CleanPeptide = ls_Peptide.gsub(/[^A-Za-z]/, '')
                            if ls_Peptide.include?('HPVKVTIGSQDLAASHSITQHVEVIEPHAR')
                                puts ls_Peptide
                                puts ls_CleanPeptide
                            end
                            if lk_ScanHash.include?(ls_ScanId)
                                # scan already there
                                if (lk_ScanHash[ls_ScanId][:cleanPeptide] != ls_CleanPeptide)
                                    #puts "ignoring ambiguous match in #{File::basename(ls_Path)}, scan id #{ls_ScanId.split('/').last}, #{lk_ScanHash[ls_ScanId][:cleanPeptide]} / #{ls_CleanPeptide}"
                                    lk_ForbiddenScanIds.add(ls_ScanId)
                                    lk_ScanHash.delete(ls_ScanId)
                                end
                            end
                            unless lk_ForbiddenScanIds.include?(ls_ScanId)
                                lk_ScanHash[ls_ScanId] ||= {:cleanPeptide => ls_CleanPeptide, :protein => ls_Protein, :mods => Set.new, :id => ls_Id }
                                ls_ModPeptide = ls_Peptide.dup
                                while (ls_ModPeptide =~ /[^A-Za-z]/)
                                    index = ls_ModPeptide.index(/[^A-Za-z]/)
                                    ls_ModPeptide[index - 1, 1] = ls_ModPeptide[index - 1, 1].downcase
                                    ls_ModPeptide.sub!(/[^A-Za-z]/, '')
                                end
                                lk_ScanHash[ls_ScanId][:mods].add(ls_ModPeptide)
                            end
                        end
                    end
                end
            else
                # TPP format
                lk_ThisProteins = Set.new
                ls_Id = File::basename(ls_Path).sub('.csv', '')
                ls_Protein = nil
                File::open(ls_Path, 'r') do |lk_File|
                    header = mapCsvHeader(lk_File.readline)
                    unless header.include?('spectrum') && header.include?('peptide') && header.include?('protein')
                        puts "Error: Not all expected columns were found in #{ls_Path}."
                        puts "Expected columns are 'spectrum', 'peptide' and 'protein'."
                        exit(1)
                    end
                    lk_File.each_line do |ls_Line|
                        lk_Line = ls_Line.parse_csv
                        ls_ScanId = sanitizeScanId(lk_Line[header['spectrum']])
                        next if (!lk_Line[header['peptide']]) || (lk_Line[header['peptide']].strip.empty?)
                        
                        # here comes a peptide
                        peptide = lk_Line[header['peptide']].strip
                        if peptide.split('.').size != 3
                            puts "Error: Expecting K.PEPTIDER.A style peptides in SEQUEST results."
                            exit 1
                        end
                        ls_Peptide = peptide.split('.')[1].strip
                        
                        ls_CleanPeptide = ls_Peptide.gsub(/[^A-Za-z]/, '')
                        ls_Protein = lk_Line[header['protein']]
                        ls_OriginalProtein = ls_Protein.dup
                        ls_Protein = ls_Protein.split(/\s/).first if @param[:useProteinIds]
                        fullProteinForProteinId[ls_Protein] ||= Set.new
                        fullProteinForProteinId[ls_Protein] << ls_OriginalProtein
                        lk_ThisProteins << ls_Protein
                        
                        lk_ScanHash[ls_ScanId] ||= {:cleanPeptide => ls_CleanPeptide, :protein => ls_Protein, :mods => Set.new, :id => ls_Id }
                        ls_ModPeptide = ls_Peptide.dup
                        while (ls_ModPeptide =~ /[^A-Za-z]/)
                            index = ls_ModPeptide.index(/[^A-Za-z]/)
                            ls_ModPeptide[index - 1, 1] = ls_ModPeptide[index - 1, 1].downcase
                            ls_ModPeptide.sub!(/[^A-Za-z]/, '')
                        end
                        lk_ScanHash[ls_ScanId][:mods].add(ls_ModPeptide)
                    end
                end
            end
            lk_ProteinsForId[ls_Id] = lk_ThisProteins
            puts "#{lk_ThisProteins.size} proteins."
        end
        
        ambiguousDescriptions = Set.new
        fullProteinForProteinId.each_pair do |key, entries|
            newEntries = entries.dup
            longestEntry = newEntries.sort { |a, b| b.size <=> a.size }.first
            newEntries.reject! do |x|
                (x != longestEntry) && (longestEntry[0, x.size] == x)
            end
            fullProteinForProteinId[key] = newEntries
            ambiguousDescriptions << key if newEntries.size > 1
        end
        
        unless ambiguousDescriptions.empty?
            puts "Warning: Something may be wrong here, because there are multiple full protein descriptions for some proteins."
            puts "This applies to #{ambiguousDescriptions.size} proteins."
            ambiguousDescriptions.to_a.sort.each do |key|
                puts "#{key}"
                fullProteinForProteinId[key].each do |full|
                    puts "    #{full}"
                end
            end
        end
        
        # merge SEQUEST results into lk_AllResults
        lk_ScanHash.each do |ls_ScanId, lk_Scan|
            ls_Protein = lk_Scan[:protein]
            ls_Peptide = lk_Scan[:cleanPeptide]
            ls_ModPeptide = lk_Scan[:mods].to_a.sort.join(' / ')
            ls_Id = lk_Scan[:id]
            lk_AllResults[ls_Protein] ||= Hash.new
            lk_AllResults[ls_Protein][ls_ModPeptide] ||= Hash.new
            lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id] ||= Set.new()
            lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id] << ls_ScanId
        end
        
        puts "Comparing #{lk_AllResults.size} proteins."
        
        lk_ProteinInterestingnessScores = Hash.new
        lk_ModPeptideInterestingnessScores = Hash.new
        lk_AllResults.each do |ls_Protein, lk_ProteinData|
            ld_Interestingness = 0.0
            lk_ProteinData.each do |ls_ModPeptide, lk_ModPeptideData|
                lk_Numbers = Hash.new
                lk_Ids.each { |x| lk_Numbers[x] = 0 }
                lk_ModPeptideData.each { |ls_Id, lk_ScanIds| lk_Numbers[ls_Id] = lk_ScanIds.size }
                ld_Mean, ld_Sd = meanAndStandardDeviation(lk_Numbers.values)
                lk_ModPeptideInterestingnessScores[ls_Protein + '/' + ls_ModPeptide] = ld_Sd
                ld_Interestingness += ld_Sd
            end
            lk_ProteinInterestingnessScores[ls_Protein] = ld_Interestingness
        end

        if @output[:peptideReport]
            File::open(@output[:peptideReport], 'w') do |f|
                f.puts "Protein,Peptide(s),#{lk_Ids.collect { |x| '"' + x + '",mod,' }.join('')}Union,Intersection"
                lk_AllResults.keys.sort { |a, b| lk_ProteinInterestingnessScores[b] <=> lk_ProteinInterestingnessScores[a] }.each do |ls_Protein|
                    lk_AllResults[ls_Protein].keys.sort { |a, b| lk_ModPeptideInterestingnessScores[ls_Protein + '/' + b] <=> lk_ModPeptideInterestingnessScores[ls_Protein + '/' + a] }.each do |ls_ModPeptide|
                        f.print "\"#{ls_Protein}\","
                        lb_IsModified = ls_ModPeptide.index(/[a-z]/)
                        ls_UnmodClass = ''
                        if lb_IsModified
                            ls_UnmodClass = ' modpep'
                        else
                            ls_UnmodClass = ' unmodpep'
                        end
                        f.print "\"#{ls_ModPeptide}\","
                        lk_Ids.each do |ls_Id|
                            li_Count = '0'
                            if lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id]
                                li_Count = lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id].size
                            end
                            f.print "#{li_Count},#{lb_IsModified ? 'mod' : '"-"'},"
                        end
                        allScans = lk_Ids.collect do |ls_Id|
                            x = Set.new()
                            if lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id]
                                x = lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id]
                            end
                            x
                        end
                        union, intersection = unionAndIntersection(allScans)
                        f.print "#{union.size}"
                        f.print ",#{intersection.size}"
                        f.puts
                    end
                end
            end
        end
        
        if @output[:proteinReport]
            File::open(@output[:proteinReport], 'w') do |f|
                f.puts "Protein,#{lk_Ids.collect { |x| '"' + x + '",mod,' }.join('')}Union,Intersection"
                lk_AllResults.keys.sort { |a, b| lk_ProteinInterestingnessScores[b] <=> lk_ProteinInterestingnessScores[a] }.each do |ls_Protein|
                    f.print "\"#{fullProteinForProteinId[ls_Protein].to_a.first}\","
                    lk_IdScans = Hash.new
                    lk_IdModScans = Hash.new
                    lk_Ids.each do |x| 
                        lk_IdScans[x] = Set.new()
                        lk_IdModScans[x] = Set.new()
                    end
                    lk_AllResults[ls_Protein].keys.each do |ls_ModPeptide|
                        lk_Ids.each do |ls_Id|
                            lk_CountScans = lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id]
                            lk_CountScans ||= Set.new()
                            lk_IdScans[ls_Id] |= lk_CountScans
                            lk_IdModScans[ls_Id] |= lk_CountScans if ls_ModPeptide =~ /[a-z]/
                        end
                    end
                    lk_Ids.each do |ls_Id|
                        li_Count = lk_IdScans[ls_Id].size
                        li_ModifiedPeptideCount = lk_IdModScans[ls_Id].size
                        f.print "#{li_Count},#{li_ModifiedPeptideCount},"
                    end
                    allScans = lk_Ids.collect do |ls_Id|
                        x = Set.new()
                        if lk_IdScans[ls_Id]
                            x = lk_IdScans[ls_Id]
                        end
                        x
                    end
                    union, intersection = unionAndIntersection(allScans)
                    f.print "#{union.size}"
                    f.print ",#{intersection.size}"
                    f.puts
                end
            end
        end

        if @output[:htmlReport]
            File::open(@output[:htmlReport], 'w') do |f|
                lk_IdNumbers = []
                lk_Ids.each { |x| lk_IdNumbers << (lk_IdNumbers.size + 1).to_s }
                f.puts "<html>"
                f.puts "<head><title>Comparison of OMSSA and SEQUEST peptide-spectral matches</title>"
                f.puts DATA.read
                f.puts "</head>"
                f.puts "<body>"
                f.puts "<table>"
                f.puts "<thead>"
                f.puts "<tr><th class='number'>No.</th><th>Run</th><th>Proteins identified</th></tr>"
                f.puts "</thead>"
                f.puts "<tbody>"
                (0...lk_Ids.size).each do |i|
                    f.puts "<tr><td class='number'>#{i + 1}</td><td>#{lk_Ids[i]}</td><td>#{lk_ProteinsForId[lk_Ids[i]].size}</td></tr>"
                end
                union, intersection = unionAndIntersection(lk_ProteinsForId.values)
                
                f.puts "<tr><td class='number'></td><td>union</td><td>#{union.size}</td></tr>"
                f.puts "<tr><td class='number'></td><td>intersection</td><td>#{intersection.size}</td></tr>"
                f.puts "</tbody>"
                f.puts "</table>"
                f.puts "<p>Total proteins: #{lk_AllResults.size}</p>"
                f.puts "<p>"
                f.puts "<span onclick=\"toggle('peptide', 'row')\" style='cursor: pointer; background-color: #ddd; border: 1px solid #888; padding: 0.2em;'>Toggle peptides</span> &nbsp;"
                f.puts "<span onclick=\"toggle('unmodpep', 'row')\" style='cursor: pointer; background-color: #ddd; border: 1px solid #888; padding: 0.2em;'>Toggle unmodified peptides</span> &nbsp;"
                f.puts "<span onclick=\"toggle('modcell', 'cell')\" style='cursor: pointer; background-color: #ddd; border: 1px solid #888; padding: 0.2em;'>Toggle modification counts</span> &nbsp;"
                f.puts "</p>"
                f.puts "<table>"
                f.puts "<thead>"
                f.puts "<tr>"
                f.print "<th>Protein</th>"
                if @param[:substituteLongNames]
                    f.print "#{lk_IdNumbers.collect { |x| '<th class=\'number\' width=\'32\'>' + x + '</th><th class=\'modcell\' width=\'32\'>mod</th>' }.join('')}"
                else
                    f.print "#{lk_IdNumbers.collect { |x| '<th class=\'number\' width=\'32\'>' + lk_Ids[lk_IdNumbers.index(x)] + '</th><th class=\'modcell\' width=\'32\'>mod</th>' }.join('')}"
                end
                f.print "<th class='number'>union</th>"
                f.print "<th class='number'>intersection</th>"
                f.puts
                f.puts "</tr>"
                f.puts "</thead>"
                f.puts "<tbody>"
                lk_AllResults.keys.sort { |a, b| lk_ProteinInterestingnessScores[b] <=> lk_ProteinInterestingnessScores[a] }.each do |ls_Protein|
                    f.puts "<tr class='protein'>"
                    printProtein = fullProteinForProteinId[ls_Protein].to_a.first
                    if printProtein[0, 9] == '__group__'
                        items = printProtein.sub('__group__', '').split("\01")
                        printProtein = "<b>protein group (#{items.size} proteins)</b><br /><ul>" + items.collect { |x| '<li>' + x + '</li>' }.join('') + "</ul>"
                    end
                    f.puts "<td>#{printProtein}</td>"
                    lk_IdScans = Hash.new
                    lk_IdModScans = Hash.new
                    lk_Ids.each do |x| 
                        lk_IdScans[x] = Set.new()
                        lk_IdModScans[x] = Set.new()
                    end
                    lk_AllResults[ls_Protein].keys.each do |ls_ModPeptide|
                        lk_Ids.each do |ls_Id|
                            lk_CountIds = lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id]
                            lk_CountIds ||= Set.new()
                            lk_IdScans[ls_Id] |= lk_CountIds
                            lk_IdModScans[ls_Id] |= lk_CountIds if ls_ModPeptide =~ /[a-z]/
                        end
                    end
                    lk_Ids.each do |ls_Id|
                        li_Count = lk_IdScans[ls_Id].size
                        li_Count = '&ndash;' if li_Count == 0
                        li_ModifiedPeptideCount = lk_IdModScans[ls_Id].size
                        li_ModifiedPeptideCount = '&ndash;' if li_ModifiedPeptideCount == 0
                        f.print "<td class=\'number\' width=\'32\'>#{li_Count}</td><td class='modcell' width=\'32\'>#{li_ModifiedPeptideCount}</td>"
                    end
                    allScans = lk_Ids.collect do |ls_Id| 
                        x = lk_IdScans[ls_Id]
                        x ||= Set.new()
                        x
                    end
                    union, intersection = unionAndIntersection(allScans)
                    f.puts "<td class='number'>#{union.size}</td>"
                    f.puts "<td class='number'>#{intersection.size}</td>"
                    f.puts "</tr>"
                    lk_AllResults[ls_Protein].keys.sort { |a, b| lk_ModPeptideInterestingnessScores[ls_Protein + '/' + b] <=> lk_ModPeptideInterestingnessScores[ls_Protein + '/' + a] }.each do |ls_ModPeptide|
                        lb_IsModified = ls_ModPeptide.index(/[a-z]/)
                        ls_UnmodClass = ''
                        if lb_IsModified
                            ls_UnmodClass = ' modpep'
                        else
                            ls_UnmodClass = ' unmodpep'
                        end
                        f.puts "<tr class='peptide#{ls_UnmodClass}'>"
                        f.puts "<td>#{ls_ModPeptide.gsub(/([a-z])/, '<b>\1</b>')}</td>"
                        lk_Ids.each do |ls_Id|
                            li_Count = '&ndash;'
                            if lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id]
                                li_Count = lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id].size
                            end
                            f.print "<td class=\'number\'>#{li_Count}</td><td class='modcell'>#{lb_IsModified ? 'mod' : '&ndash;'}</td>"
                        end
                        allScans = lk_Ids.collect do |ls_Id| 
                            x = lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id]
                            x ||= Set.new()
                            x
                        end
                        union, intersection = unionAndIntersection(allScans)
                        f.puts "<td class='number'>#{union.size}</td>"
                        f.puts "<td class='number'>#{intersection.size}</td>"
                        f.puts "</tr>"
                    end
                end
                f.puts "</tbody>"
                f.puts "</table>"
                f.puts "<p>This HTML document uses a <a href='http://www.shawnolson.net/a/503/altering-css-class-attributes-with-javascript.html'>JavaScript snippet</a> by Shawn Olson.</p>"
                f.puts "</body>"
                f.puts "</html>"
            end
        end
    end
end


script = ComparePsmMod.new()


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

<script type='text/javascript'>
//Custom JavaScript Functions by Shawn Olson
//Copyright 2006-2008
//http://www.shawnolson.net
//If you copy any functions from this page into your scripts, you must provide credit to Shawn Olson & http://www.shawnolson.net
//*******************************************

    function stripCharacter(words,character) {
    //documentation for this script at http://www.shawnolson.net/a/499/
      var spaces = words.length;
      for(var x = 1; x<spaces; ++x){
       words = words.replace(character, "");
     }
     return words;
    }

        function changecss(theClass,element,value) {
    //Last Updated on June 23, 2009
    //documentation for this script at
    //http://www.shawnolson.net/a/503/altering-css-class-attributes-with-javascript.html
     var cssRules;

     var added = false;
     for (var S = 0; S < document.styleSheets.length; S++){

    if (document.styleSheets[S]['rules']) {
      cssRules = 'rules';
     } else if (document.styleSheets[S]['cssRules']) {
      cssRules = 'cssRules';
     } else {
      //no rules found... browser unknown
     }

      for (var R = 0; R < document.styleSheets[S][cssRules].length; R++) {
       if (document.styleSheets[S][cssRules][R].selectorText == theClass) {
        if(document.styleSheets[S][cssRules][R].style[element]){
        document.styleSheets[S][cssRules][R].style[element] = value;
        added=true;
        break;
        }
       }
      }
      if(!added){
      if(document.styleSheets[S].insertRule){
              document.styleSheets[S].insertRule(theClass+' { '+element+': '+value+'; }',document.styleSheets[S][cssRules].length);
            } else if (document.styleSheets[S].addRule) {
                document.styleSheets[S].addRule(theClass,element+': '+value+';');
            }
      }
     }
    }

    function checkUncheckAll(theElement) {
     var theForm = theElement.form, z = 0;
     for(z=0; z<theForm.length;z++){
      if(theForm[z].type == 'checkbox' && theForm[z].name != 'checkall'){
      theForm[z].checked = theElement.checked;
      }
     }
    }

function checkUncheckSome(controller,theElements) {
    //Programmed by Shawn Olson
    //Copyright (c) 2006-2007
    //Updated on August 12, 2007
    //Permission to use this function provided that it always includes this credit text
    //  http://www.shawnolson.net
    //Find more JavaScripts at http://www.shawnolson.net/topics/Javascript/

    //theElements is an array of objects designated as a comma separated list of their IDs
    //If an element in theElements is not a checkbox, then it is assumed
    //that the function is recursive for that object and will check/uncheck
    //all checkboxes contained in that element

     var formElements = theElements.split(',');
     var theController = document.getElementById(controller);
     for(var z=0; z<formElements.length;z++){
      theItem = document.getElementById(formElements[z]);
      if(theItem.type){
        if (theItem.type=='checkbox') {
            theItem.checked=theController.checked;
        }
      } else {
            theInputs = theItem.getElementsByTagName('input');
      for(var y=0; y<theInputs.length; y++){
      if(theInputs[y].type == 'checkbox' && theInputs[y].id != theController.id){
         theInputs[y].checked = theController.checked;
        }
      }
      }
    }
}

    function changeImgSize(objectId,newWidth,newHeight) {
      imgString = 'theImg = document.getElementById("'+objectId+'")';
      eval(imgString);
      oldWidth = theImg.width;
      oldHeight = theImg.height;
      if(newWidth>0){
       theImg.width = newWidth;
      }
      if(newHeight>0){
       theImg.height = newHeight;
      }

    }

    function changeColor(theObj,newColor){
      eval('var theObject = document.getElementById("'+theObj+'")');
      if(theObject.style.backgroundColor==null){theBG='white';}else{theBG=theObject.style.backgroundColor;}
      if(theObject.style.color==null){theColor='black';}else{theColor=theObject.style.color;}
      //alert(theObject.style.color+' '+theObject.style.backgroundColor);
      switch(theColor){
        case newColor:
          switch(theBG){
            case 'white':
              theObject.style.color = 'black';
            break;
            case 'black':
              theObject.style.color = 'white';
              break;
            default:
              theObject.style.color = 'black';
              break;
          }
          break;
        default:
          theObject.style.color = newColor;
          break;
      }
    }
    
    var visible = new Array();
    visible['protein'] = true;
    visible['peptide'] = true;
    visible['unmodpep'] = true;
    visible['modcell'] = true;
    
    function toggle(key, rowOrCol)
    {
        if (visible[key])
            changecss('.' + key, 'display', 'none');
        else
            changecss('.' + key, 'display', 'table-' + rowOrCol);
        visible[key] = !visible[key]
        if (key == 'peptide')
        {
            visible['unmodpep'] = visible['peptide']
            changecss('.unmodpep', 'display', null);
        }
        if (key == 'unmodpep')
        {
            visible['peptide'] = true
            changecss('.peptide', 'display', null);
        }
    }
</script>
