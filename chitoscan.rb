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
require 'include/externaltools'
require 'include/misc'
require 'yaml'
require 'fileutils'

class ChitoScan < ProteomaticScript

	def run()
		ls_Command = "\"#{ExternalTools::binaryPath('chitinator.chitoscan')}\""
		ls_Command += " --writeCompositionFingerprint \"#{@output[:compositionFingerprint]}\"" if @output[:compositionFingerprint]
		ls_Command += " --writeMassRangeFingerprint \"#{@output[:massRangeFingerprint]}\"" if @output[:massRangeFingerprint]
		ls_Command += " --writeMassCollisionFingerprint \"#{@output[:massCollisionFingerprint]}\"" if @output[:massCollisionFingerprint]
		ls_Command += ' ' + @mk_Parameters.commandLineFor('chitinator.chitoscan')
		ls_Command += ' ' + @input[:spectra].collect { |x| '"' + x + '"' }.join(' ')
		runCommand(ls_Command, true)
	end
end

lk_Object = ChitoScan.new
