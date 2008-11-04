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

def wrap(as_String, ai_Width = 70)
	i = ai_Width
	ls_Result = as_String.dup
	while (i < ls_Result.size)
		ls_Result.insert(i, "\n")
		i += ai_Width + 1
	end
	return ls_Result
end

def setupAminoAcids()
	ls_Info = DATA.read()
	ls_Info.each do |ls_Line|
		ls_Line.strip!
		lk_Line = ls_Line.split(';')
		#next if lk_Line[0].include?('N')
		$gk_NtoAA[lk_Line[0]] = lk_Line.last
		$gk_AAtoN[lk_Line[1]] ||= Array.new
		$gk_AAtoN[lk_Line[1]].push(lk_Line[0])
	end
end


def handleEntry(as_Id, as_Content)
	(0..1).each do |li_Reverse|
		(0..2).each do |li_Frame|
			puts "#{as_Id} (frame #{li_Frame + 1 + li_Reverse * 3})"
			ls_Content = as_Content.dup
			ls_Protein = ''
			if (li_Reverse > 0)
				ls_Content.reverse!
				ls_Content.gsub!('A', '/')
				ls_Content.gsub!('T', 'A')
				ls_Content.gsub!('/', 'T')
				ls_Content.gsub!('G', '/')
				ls_Content.gsub!('C', 'G')
				ls_Content.gsub!('/', 'C')
			end
			ls_Content.slice!(0..(li_Frame - 1)) if li_Frame > 0
			while (ls_Content.length >= 3)
				ls_Triplet = ls_Content.slice!(0..2)
				ls_Triplet.gsub!('T', 'U')
				ls_AminoAcid = $gk_NtoAA[ls_Triplet]
				puts ls_Triplet if (!ls_AminoAcid)
				
				ls_Protein += ls_AminoAcid
			end
			puts wrap(ls_Protein)
		end
	end
end


def handleFile(as_Path)
	File::open(as_Path, 'r') do |lk_File|
		ls_Id = ''
		ls_Content = ''		
		lk_File.each do |ls_Line|
			ls_Line.strip!
			if (ls_Line[0, 1] == '>')
				handleEntry(ls_Id, ls_Content) unless (ls_Id.empty?)
				ls_Id = ls_Line 
			else
				ls_Content += ls_Line
			end
		end
		handleEntry(ls_Id, ls_Content) unless (ls_Id.empty?)
	end
end

setupAminoAcids()

handleFile('/home/michael/Desktop/Taraxacum_EST_041108.fasta')
#handleFile('/home/michael/Desktop/one-seq.fasta')

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
