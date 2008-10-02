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

require 'fileutils'
require 'include/externaltools'

def iterateFastaEntries(as_Filename)
	lk_In = File.open(as_Filename)
	ls_CurrentId = ''
	ls_CurrentPeptide = ''
	lk_In.each do |ls_Line|
		ls_Line.chomp!
		if (ls_Line[0, 1] == '>')
			yield(ls_CurrentId, ls_CurrentPeptide) if !ls_CurrentId.empty?
			ls_CurrentId = ls_Line[1, ls_Line.length - 1].strip
			ls_CurrentPeptide = ''
		else
			ls_CurrentPeptide += ls_Line
		end
	end
	yield(ls_CurrentId, ls_CurrentPeptide) if !ls_CurrentId.empty?
end


def shufflePeptide(as_Peptide)
	return as_Peptide if (as_Peptide.size < 2)
	ls_LastChar = as_Peptide[as_Peptide.length - 1, 1]
	ls_Chopped = as_Peptide.chop
	ls_Result = ''
	while (!ls_Chopped.empty?)
		li_Index = rand(ls_Chopped.length)
		ls_Result += ls_Chopped[li_Index, 1]
		ls_Chopped[li_Index, 1] = ls_Chopped[ls_Chopped.length - 1, 1]
		ls_Chopped.chop!
	end
	ls_Result += ls_LastChar
	return ls_Result
end


def getTargetDecoyFilename(as_Filename)
	ls_CachePath = File::join(File.dirname(as_Filename), '.proteomatic', 'fasta')
	if (File.exists?(ls_CachePath))
		if (File.file?(ls_CachePath))
			puts "Error: There is already a file named #{ls_CachePath}, cannot proceed with it in the way."
			exit 1
		end
	else
		FileUtils.mkpath(ls_CachePath)
	end
	return File::join(ls_CachePath, File.basename(as_Filename) + '.target-decoy.fasta')
end


def createTargetDecoyDatabase(as_Filename)
	ls_TargetDecoyFilename = getTargetDecoyFilename(as_Filename)
	
	# create target/decoy database if necessary
	if !FileUtils.uptodate?(ls_TargetDecoyFilename, [as_Filename])
		lk_Out = File.open(ls_TargetDecoyFilename + '.proteomatic.part', 'w')
		iterateFastaEntries(as_Filename) do |ls_Id, ls_Peptide|
			ls_Shuffled = shufflePeptide(ls_Peptide)
			lk_Out.puts ">target_#{ls_Id}"
			li_Index = 80
			while (li_Index < ls_Peptide.length)
				ls_Peptide.insert(li_Index, "\n")
				li_Index += 81
			end
			lk_Out.puts ls_Peptide
			lk_Out.puts ">decoy_#{ls_Id}"
			li_Index = 80
			while (li_Index < ls_Shuffled.length)
				ls_Shuffled.insert(li_Index, "\n")
				li_Index += 81
			end
			lk_Out.puts ls_Shuffled
		end
		lk_Out.close()
		File.rename(ls_TargetDecoyFilename + '.proteomatic.part', ls_TargetDecoyFilename)
	end
end

def createBlastDatabase(as_Filename)
	# create blast database if necessary
	# .phr .psq .pin
	begin
		if (!FileUtils.uptodate?(as_Filename + '.phr', [as_Filename]) ||
			!FileUtils.uptodate?(as_Filename + '.psq', [as_Filename]) ||
			!FileUtils.uptodate?(as_Filename + '.pin', [as_Filename]))
			system("\"#{ExternalTools::binaryPath('blast.formatdb')}\" -i \"#{as_Filename}\" -p T -o F");
			File.delete('formatdb.log') if File.exists?('formatdb.log')
		end
	rescue
		FileUtils.rm_f([as_Filename + '.phr', as_Filename + '.psq', as_Filename + '.pin'])
	end
end


