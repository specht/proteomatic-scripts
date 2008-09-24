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

def stddev(ak_Values)
	lf_Mean = 0.0
	ak_Values.each { |f| lf_Mean += f.to_f }
	lf_Mean /= ak_Values.size
	
	lf_Sum = 0.0
	ak_Values.each { |f| lf_Sum += (f.to_f - lf_Mean) * (f.to_f - lf_Mean) }
	return Math.sqrt(lf_Sum / ak_Values.size)
end


def wordwrap(as_String, ai_MaxLength = 70)
	lk_RegExp = Regexp.new('.{1,' + ai_MaxLength.to_s + '}(?:\s|\Z)')
	as_String.gsub(/\t/,"     ").gsub(lk_RegExp){($& + 5.chr).gsub(/\n\005/,"\n").gsub(/\005/,"\n")}
end


def indent(as_String, ai_Indent = 4, ab_FirstLine = true)
	ls_Indent = ''
	ai_Indent.times { ls_Indent += ' ' }
	ls_FirstIndent = ''
	ls_FirstIndent = ls_Indent if ab_FirstLine
	ls_FirstIndent + as_String.gsub("\n", "\n" + ls_Indent)
end


def underline(as_String, ac_Char)
	ls_Result = as_String + "\n"
	as_String.length.times { ls_Result += ac_Char }
	ls_Result += "\n"
	return ls_Result
end


def bytesToString(ai_Size)
	if ai_Size < 1024
		return "#{ai_Size} bytes"
	elsif ai_Size < 1024 * 1024
		return "#{sprintf('%1.2f', ai_Size.to_f / 1024.0)} KB"
	elsif ai_Size < 1024 * 1024 * 1024
		return "#{sprintf('%1.2f', ai_Size.to_f / 1024.0 / 1024.0)} MB"
	end
	return "#{sprintf('%1.2f', ai_Size.to_f / 1024.0 / 1024.0 / 1024.0)} GB"
end


def stringEndsWith(as_String, as_End, ab_CaseSensitive = true)
	return false if as_String.size < as_End.size
	if ab_CaseSensitive
		return (as_String[-as_End.size, as_End.size] <=> as_End) == 0
	else
		return as_End.casecmp(as_String[-as_End.size, as_End.size]) == 0
	end
end


def determinePlatform()
	case RUBY_PLATFORM.downcase
	when /linux/
		'linux'
	when /darwin/
		'mac'
	when /mswin/
		'windows'
	else
		puts "Internal error: #{RUBY_PLATFORM} platform not supported."
		exit 1
	end
end


def mergeCsvFiles(ak_Files, as_OutFilename)
	lk_File = File.open(ak_Files.first, 'r')
	# read header from first file
	ls_Header = lk_File.readline
	lk_File.close()
	
	lk_Out = File.open(as_OutFilename, 'w')
	lk_Out.write(ls_Header)
	
	ak_Files.each do |ls_Filename|
		lk_File = File.open(ls_Filename, 'r')
		# skip csv header
		lk_File.readline
		lk_Out.write(lk_File.read)
		lk_File.close()
	end
	
	lk_Out.close()
end


class String
	# 'Natural order' comparison of two strings
	def String.natcmp(str1, str2, caseInsensitive=false)
		str1, str2 = str1.dup, str2.dup
		compareExpression = /^(\D*)(\d*)(.*)$/
	
		if caseInsensitive
			str1.downcase!
			str2.downcase!
		end
	
		# Remove all whitespace
		str1.gsub!(/\s*/, '')
		str2.gsub!(/\s*/, '')
	
		while (str1.length > 0) or (str2.length > 0) do
			# Extract non-digits, digits and rest of string
			str1 =~ compareExpression
			chars1, num1, str1 = $1.dup, $2.dup, $3.dup
	
			str2 =~ compareExpression
			chars2, num2, str2 = $1.dup, $2.dup, $3.dup
	
			# Compare the non-digits
			case (chars1 <=> chars2)
				when 0 # Non-digits are the same, compare the digits...
					# If either number begins with a zero, then compare alphabetically,
					# otherwise compare numerically
					if (num1[0] != 48) and (num2[0] != 48)
						num1, num2 = num1.to_i, num2.to_i
					end
	
					case (num1 <=> num2)
						when -1 then return -1
						when 1 then return 1
					end
				when -1 then return -1
				when 1 then return 1
			end # case
	
		end # while
	
		# Strings are naturally equal
		return 0
	end
	
end # class String
		