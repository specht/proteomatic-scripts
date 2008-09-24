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

# A: 0.1796
# C: 0.3202
# G: 0.3204
# T: 0.1798

require 'yaml'
require 'set'

$gk_NtoAA = Hash.new
$gk_AAtoN = Hash.new

def setupAminoAcids()
	ls_Info = DATA.read()
	ls_Info.each do |ls_Line|
		ls_Line.strip!
		lk_Line = ls_Line.split(';')
		next if lk_Line[0].include?('N')
		$gk_NtoAA[lk_Line[0]] = lk_Line[1]
		$gk_AAtoN[lk_Line[1]] ||= Array.new
		$gk_AAtoN[lk_Line[1]].push(lk_Line[0])
	end
end


def findCombinations(as_Peptide, ai_Start, ai_Length)
	ls_Stretched = ''
	(0...as_Peptide.length).each { |i| x = as_Peptide[i, 1]; ls_Stretched += x + x + x }
	(0...ai_Start).each { |i| ls_Stretched[i, 1] = '.' }
	((ai_Start + ai_Length)...ls_Stretched.length).each { |i| ls_Stretched[i, 1] = '.' }
	li_Combinations = 1
	while (!ls_Stretched.empty?) do
		ls_Piece = ls_Stretched.slice!(0, 3)
		next if (ls_Piece == '...')
		ls_Char = ls_Piece.gsub('.', '')[0, 1]
		if (!ls_Piece.include?('.'))
			li_Combinations *= $gk_AAtoN[ls_Char].size()
		else
			lk_Combinations = Array.new
			$gk_AAtoN[ls_Char].each do |ls_Nucleotides|
				ls_Copy = ''
				(0...3).each { |i| ls_Copy += ls_Piece[i, 1] == '.' ? '.' : ls_Nucleotides[i, 1]  }
				lk_Combinations.push(ls_Copy)
			end
			lk_Combinations.uniq!
			li_Combinations *= lk_Combinations.size
		end
	end
	return li_Combinations
end


def handleFile(ak_Files, ak_Out = $stdout)
	lk_Peptides = Hash.new
	# merge all results, overwrite duplicate keys (values should be the same anyway)
	ak_Files.each { |ls_Path| lk_Peptides.merge!(YAML::load_file(ls_Path)) }
		
	lk_Peptides.each do |ls_Peptide, lk_Hits|
		li_AssemblyCount = lk_Hits.size
		next if li_AssemblyCount == 0

		# chuck out intron split assemblies when there are non-intron split assemblies
		# available

		lb_HasImmediateHits = false
		lk_Hits.each { |lk_Assembly| lb_HasImmediateHits = true if lk_Assembly['details']['parts'].size == 1 }
		if lb_HasImmediateHits
			lk_Hits.reject! { |lk_Assembly|	lk_Assembly['details']['parts'].size != 1 }
		end
	
		# adjust positions if reverse (from GPF to GFF)
		lk_Hits.each_index do |li_AssemblyIndex|
			lk_Assembly = lk_Hits[li_AssemblyIndex]
			if lk_Assembly['details']['forward']
				lk_Assembly['details']['parts'].each { |lk_Part| lk_Part['position'] += 1 } 
			else
				lk_Assembly['details']['parts'].each { |lk_Part| lk_Part['position'] = lk_Part['position'] - lk_Part['length'] + 2 } 
			end
			lk_Hits[li_AssemblyIndex] = lk_Assembly
		end
		
		# in the examples, nrhits had as many entries as hits, so I don't know what this is about
		lk_NrHits = lk_Hits.collect { |x| {'parts' => x['details']['parts'], 'peptide' => x['peptide'], 'forward' => x['details']['forward']} }
		lk_NrHits = lk_NrHits.collect { |x| x.to_yaml }.uniq.collect { |x| YAML::load(x) }
		li_AssemblyCount = lk_NrHits.size
		
		lk_PeptideCombinations = Hash.new
		
		lk_AllSpans = Array.new
		lk_NrHits.each do |lk_Assembly|
			lk_Spans = Array.new
			li_NucleotideCount = 0
			lk_Assembly['parts'].each do |lk_Part|
				li_Frame = (3 - (li_NucleotideCount % 3)) % 3
				li_Start = lk_Part['position']
				li_End = lk_Part['position'] + lk_Part['length'] - 1
				lk_Spans.push({
					:start => li_Start,
					:end => li_End,
					:frame => li_Frame,
					:length => lk_Part['length'],
					:peptide => lk_Assembly['peptide'],
					:forward => lk_Assembly['forward'],
					:scaffold => lk_Assembly['parts'].first['scaffold'],
					:assemblyStart => li_NucleotideCount
				})
				li_NucleotideCount += li_End - li_Start + 1
			end
			# chuck out all CDS that are shorter than 4 nucleotides
			#lk_Spans.reject! { |lk_Span| lk_Span[:length] < 4 }
			ls_Peptide = lk_Assembly['peptide']
			lk_PeptideCombinations[ls_Peptide] ||= Hash.new
			lk_Spans.each do |lk_Span|
				ls_Key = "#{lk_Span[:assemblyStart]}:#{lk_Span[:length]}"
				lk_PeptideCombinations[ls_Peptide][ls_Key] = findCombinations(lk_Span[:peptide], lk_Span[:assemblyStart], lk_Span[:length])
			end
			lk_AllSpans.push(lk_Spans)
		end
		
		# chuck out assembly parts that are not statistically significant
		lk_AllSpans.each do |lk_Spans|
			lk_Spans.reject! do |lk_Span|
				ls_Peptide = lk_Span[:peptide]
				ls_Key = "#{lk_Span[:assemblyStart]}:#{lk_Span[:length]}"
				li_Combinations = lk_PeptideCombinations[ls_Peptide][ls_Key]
				q = li_Combinations.to_f / (4.0**lk_Span[:length].to_f)
				p = 1.0 - ((1.0 - q)**2100.0)
				puts "#{ls_Peptide} (#{ls_Key}): #{p}"
			end
		end
		
		# chuck out duplicate span lists (these might appear because assembly parts have been chucked out)
		li_AssemblyId = 0
		lk_AllSpans = lk_AllSpans.collect { |x| x.to_yaml }.uniq.collect{ |x| YAML::load(x) }
		lk_AllSpans.each do |lk_Spans|
			li_AssemblyId += 1
			li_Min = nil
			li_Max = nil
			lk_Spans.each do |lk_Span|
				li_Min = lk_Span[:start] unless li_Min
				li_Max = lk_Span[:start] unless li_Max
				li_Min = lk_Span[:start] if lk_Span[:start] < li_Min
				li_Min = lk_Span[:end] if lk_Span[:end] < li_Min
				li_Max = lk_Span[:start] if lk_Span[:start] > li_Max
				li_Max = lk_Span[:end] if lk_Span[:end] > li_Max
			end
			
			ls_Scaffold = lk_Spans.first[:scaffold]
			ak_Out.puts "#{ls_Scaffold}\tGPF\tassembly\t#{li_Min}\t#{li_Max}\t1.0\t#{lk_Spans.first[:forward] ? '+' : '-'}\t0\tpept=#{lk_Spans.first[:peptide]};mult=#{lk_AllSpans.size};grp=#{lk_Spans.first[:peptide]}-#{li_AssemblyId};"
			(0...lk_Spans.size).each do |li_Index|
				lk_Span = lk_Spans[li_Index]
				# cds
				ak_Out.puts "#{ls_Scaffold}\tGPF\tCDS\t#{lk_Span[:start]}\t#{lk_Span[:end]}\t1.0\t#{lk_Spans.first[:forward] ? '+' : '-'}\t#{lk_Span[:frame]}\tpept=#{lk_Spans.first[:peptide]};mult=#{lk_AllSpans.size};grp=#{lk_Spans.first[:peptide]}-#{li_AssemblyId};"
				if (lk_Span != lk_Spans.last)
					# intron
					if (lk_Span[:forward])
						ak_Out.puts "#{ls_Scaffold}\tGPF\tintron\t#{lk_Span[:end] + 1}\t#{lk_Spans[li_Index + 1][:start] - 1}\t1.0\t#{lk_Span[:forward] ? '+' : '-'}\t.\tpept=#{lk_Span[:peptide]};mult=#{lk_AllSpans.size};grp=#{lk_Span[:peptide]}-#{li_AssemblyId};"
					else
						ak_Out.puts "#{ls_Scaffold}\tGPF\tintron\t#{lk_Spans[li_Index + 1][:end] + 1}\t#{lk_Span[:start] - 1}\t1.0\t#{lk_Span[:forward] ? '+' : '-'}\t.\tpept=#{lk_Span[:peptide]};mult=#{lk_AllSpans.size};grp=#{lk_Span[:peptide]}-#{li_AssemblyId};"
					end
				end
			end
		end
	end
end

setupAminoAcids()
File::open('/home/michael/Augustus/gpf-alignments.gff', 'w') { |f| handleFile(['/home/michael/Augustus/omssa/MT_HydACPAN-augustus-peptides.yaml', 
'/home/michael/Augustus/omssa/MT_HydACPAR-augustus-peptides.yaml'], f) }

__END__
AAA;K
AAC;N
AAG;K
AAU;N
AAN;K;X
ACA;T
ACC;T
ACG;T
ACU;T
ACN;T
AGA;R
AGC;S
AGG;R
AGU;S
AGN;R;X
AUA;I
AUC;I
AUG;M
AUU;I
AUN;I;X
ANA;X
ANC;X
ANG;X
ANU;X
ANN;X
CAA;Q
CAC;H
CAG;Q
CAU;H
CAN;Q;X
CCA;P
CCC;P
CCG;P
CCU;P
CCN;P
CGA;R
CGC;R
CGG;R
CGU;R
CGN;R
CUA;L
CUC;L
CUG;L
CUU;L
CUN;L
CNA;X
CNC;X
CNG;X
CNU;X
CNN;X
GAA;E
GAC;D
GAG;E
GAU;D
GAN;D;X
GCA;A
GCC;A
GCG;A
GCU;A
GCN;A
GGA;G
GGC;G
GGG;G
GGU;G
GGN;G
GUA;V
GUC;V
GUG;V
GUU;V
GUN;V
GNA;X
GNC;X
GNG;X
GNU;X
GNN;X
UAA;$
UAC;Y
UAG;$
UAU;Y
UAN;Y;X
UCA;S
UCC;S
UCG;S
UCU;S
UCN;S
UGA;$
UGC;C
UGG;W
UGU;C
UGN;C;X
UUA;L
UUC;F
UUG;L
UUU;F
UUN;L;X
UNA;X
UNC;X
UNG;X
UNU;X
UNN;X
NAA;X
NAC;X
NAG;X
NAU;X
NAN;X
NCA;X
NCC;X
NCG;X
NCU;X
NCN;X
NGA;X
NGC;X
NGG;X
NGU;X
NGN;X
NUA;X
NUC;X
NUG;X
NUU;X
NUN;X
NNA;X
NNC;X
NNG;X
NNU;X
NNN;X
