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

def createBlastDatabase(as_Filename)
	# create blast database if necessary
	# .phr .psq .pin
	begin
		if (!FileUtils.uptodate?(as_Filename + '.phr', [as_Filename]) ||
			!FileUtils.uptodate?(as_Filename + '.psq', [as_Filename]) ||
			!FileUtils.uptodate?(as_Filename + '.pin', [as_Filename]))
			ls_Command = "\"#{ExternalTools::binaryPath('blast.formatdb')}\" -i \"#{as_Filename}\" -p T -o F"
			unless system(ls_Command)
				puts 'Error: There was an error while executing formatdb.'
				exit(1)
			end
			File.delete('formatdb.log') if File.exists?('formatdb.log')
		end
	rescue
		FileUtils.rm_f([as_Filename + '.phr', as_Filename + '.psq', as_Filename + '.pin'])
	end
end
