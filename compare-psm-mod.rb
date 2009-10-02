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

require 'include/proteomatic'
require 'include/evaluate-omssa-helper'
require 'include/ext/fastercsv'
require 'include/misc'
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


class ComparePsmMod < ProteomaticScript
	def run()
		lk_Files = @input[:sequestResults] + @input[:omssaResults]
		lk_Ids = lk_Files.collect { |x| File::basename(x).sub('.csv', '') }.sort

		# lk_AllResults:
		#   protein 1:
		#     PEPTiDE: 
		#       id1: 5
		#       id2: 8
		lk_AllResults = Hash.new
		
		# parse OMSSA CSV files
		@input[:omssaResults].each do |ls_Path|
			print "#{File::basename(ls_Path)}: "
			ls_Id = File::basename(ls_Path).sub('.csv', '')
			lk_Results = loadPsm(ls_Path, :silent => true)
			#puts lk_Results.to_yaml
			# lk_Results[:proteins] => {'protein' => ['pep1', 'pep2']}
			# lk_Results[:peptideHash] => {'peptide' => {:scans => [scans...]}}
			puts "#{lk_Results[:proteins].size} proteins."
			lk_Results[:proteins].keys.each do |ls_Protein|
				lk_Results[:proteins][ls_Protein].each do |ls_Peptide|
					lk_Results[:peptideHash][ls_Peptide][:scans].each do |ls_Scan|
						# initialize ls_ModPeptide with clean unmodified peptide
						ls_ModPeptide = ls_Peptide
						# if there's a modification, update ls_ModPeptide
						unless lk_Results[:scanHash][ls_Scan][:mods].empty?
							ls_ModPeptide = lk_Results[:scanHash][ls_Scan][:mods].collect { |x| x[:peptide] }.sort.join(' / ')
						end
						lk_AllResults[ls_Protein] ||= Hash.new
						lk_AllResults[ls_Protein][ls_ModPeptide] ||= Hash.new
						lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id] ||= 0
						lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id] += 1
					end
				end
			end
		end

		lk_ScanHash = Hash.new
		# parse SEQUEST CSV files, collect all unambiguous scans
		@input[:sequestResults].each do |ls_Path|
			print "#{File::basename(ls_Path)}: "
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
						lk_ThisProteins << ls_Protein
						next
					end
					if (ls_Protein && lk_Line[2])
						# here comes a peptide
						ls_ScanId = File::basename(ls_Path) + '.' + lk_Line[1]
						next if lk_ForbiddenScanIds.include?(ls_ScanId)
						if lk_Line[2].split('.').size != 3
							puts "Error: Expecting K.PEPTIDER.A style peptides in SEQUEST results."
							exit 1
						end
						ls_Peptide = lk_Line[2].split('.')[1].strip
						ls_CleanPeptide = ls_Peptide.gsub(/[^A-Za-z]/, '')
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
			puts "#{lk_ThisProteins.size} proteins."
		end
		
		# merge SEQUEST results into lk_AllResults
		lk_ScanHash.each do |ls_ScanId, lk_Scan|
			ls_Protein = lk_Scan[:protein]
			ls_Peptide = lk_Scan[:cleanPeptide]
			ls_ModPeptide = lk_Scan[:mods].to_a.sort.join(' / ')
			ls_Id = lk_Scan[:id]
			lk_AllResults[ls_Protein] ||= Hash.new
			lk_AllResults[ls_Protein][ls_ModPeptide] ||= Hash.new
			lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id] ||= 0
			lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id] += 1
		end

		puts "Comparing #{lk_AllResults.size} proteins."
		
		lk_ProteinInterestingnessScores = Hash.new
		lk_ModPeptideInterestingnessScores = Hash.new
		lk_AllResults.each do |ls_Protein, lk_ProteinData|
			ld_Interestingness = 0.0
			lk_ProteinData.each do |ls_ModPeptide, lk_ModPeptideData|
				lk_Numbers = Hash.new
				lk_Ids.each { |x| lk_Numbers[x] = 0 }
				lk_ModPeptideData.each { |ls_Id, li_Count| lk_Numbers[ls_Id] = li_Count }
				ld_Mean, ld_Sd = meanAndStandardDeviation(lk_Numbers.values)
				lk_ModPeptideInterestingnessScores[ls_Protein + '/' + ls_ModPeptide] = ld_Sd
				ld_Interestingness += ld_Sd
			end
			lk_ProteinInterestingnessScores[ls_Protein] = ld_Interestingness
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
				f.puts "<tr><th class='number'>No.</th><th>Run</th></tr>"
				(0...lk_Ids.size).each do |i|
					f.puts "<tr><td class='number'>#{i + 1}</td><td>#{lk_Ids[i]}</td></tr>"
				end
				f.puts "</table>"
				f.puts "<p>"
				f.puts "<span onclick=\"toggle('peptide')\" style='cursor: pointer; background-color: #ddd; border: 1px solid #888; padding: 0.2em;'>Toggle peptides</span> &nbsp;"
				f.puts "</p>"
				f.puts "<table>"
				f.puts "<tr>"
				f.puts "<th>Protein</th>#{lk_IdNumbers.collect { |x| '<th class=\'number\'>' + x + '</th>' }.join('')}"
				f.puts "</tr>"
				lk_AllResults.keys.sort { |a, b| lk_ProteinInterestingnessScores[b] <=> lk_ProteinInterestingnessScores[a] }.each do |ls_Protein|
					f.puts "<tr class='protein'>"
					f.puts "<td>#{ls_Protein}</td>"
					lk_IdSums = Hash.new
					lk_IdModSums = Hash.new
					lk_Ids.each do |x| 
						lk_IdSums[x] = 0
						lk_IdModSums[x] = 0
					end
					lk_AllResults[ls_Protein].keys.each do |ls_ModPeptide|
						lk_Ids.each do |ls_Id|
							li_Count = lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id]
							li_Count ||= 0
							lk_IdSums[ls_Id] += li_Count
							lk_IdModSums[ls_Id] += li_Count if ls_ModPeptide =~ /[a-z]/
						end
					end
					lk_Ids.each do |ls_Id|
						li_Count = lk_IdSums[ls_Id]
						li_Count = '&ndash;' if li_Count == 0
						li_ModifiedPeptideCount = lk_IdModSums[ls_Id]
						li_ModifiedPeptideCount = '&ndash;' if li_ModifiedPeptideCount == 0
						f.print "<td class=\'number\'>#{li_Count}&nbsp;(#{li_ModifiedPeptideCount})</td>"
					end
					f.puts "</tr>"
					lk_AllResults[ls_Protein].keys.sort { |a, b| lk_ModPeptideInterestingnessScores[ls_Protein + '/' + b] <=> lk_ModPeptideInterestingnessScores[ls_Protein + '/' + a] }.each do |ls_ModPeptide|
						f.puts "<tr class='peptide'>"
						f.puts "<td>#{ls_ModPeptide.gsub(/([a-z])/, '<b>\1</b>')}</td>"
						lk_Ids.each do |ls_Id|
							li_Count = lk_AllResults[ls_Protein][ls_ModPeptide][ls_Id]
							li_Count ||= '&ndash;'
							f.print "<td class=\'number\'>#{li_Count}</td>"
						end
						f.puts "</tr>"
					end
				end
				f.puts "</table>"
				f.puts "<p>This HTML document uses a <a href='http://www.shawnolson.net/a/503/altering-css-class-attributes-with-javascript.html'>JavaScript snippet</a> by Shawn Olson.</p>"
				f.puts "</body>"
				f.puts "</html>"
			end
		end
	end
end


lk_Object = ComparePsmMod.new()


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
	function toggle(key)
	{
		if (visible[key])
			changecss('.' + key, 'display', 'none');
		else
			changecss('.' + key, 'display', 'table-row');
		visible[key] = !visible[key]
	}
</script>
