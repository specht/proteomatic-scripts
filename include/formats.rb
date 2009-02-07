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

require 'yaml'

$gk_FormatCache = Hash.new

def formatInfo(as_Format)
	ls_FormatFile = "include/formats/#{as_Format}.yaml"
	if (!File.exists?(ls_FormatFile))
		puts "Internal error: Could not find format file for #{as_Format}"
		exit 1
	end
	lk_Format = nil
	if $gk_FormatCache.has_key?(as_Format)
		lk_Format = $gk_FormatCache[as_Format]
	else
		lk_Format = YAML::load_file(ls_FormatFile)
		lk_Format['extensions'].collect! { |x| x.downcase }
		$gk_FormatCache[as_Format] = lk_Format
	end
	return lk_Format
end


def fileMatchesFormat(as_Filename, as_Format)
	lk_Format = formatInfo(as_Format)
	# match file extension
	lb_ExtensionMatches = false
	lk_Format['extensions'].each do |ls_Extension|
		if (as_Filename.downcase.rindex(ls_Extension.downcase) == as_Filename.size - ls_Extension.size)
			lb_ExtensionMatches = true
			break
		end
	end
	return false unless lb_ExtensionMatches
	# if we came through this, throw in a return true 'for good measure'
	return true
end


def assertFormat(as_Format)
	formatInfo(as_Format)
end
