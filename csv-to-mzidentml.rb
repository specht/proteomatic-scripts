#! /usr/bin/env ruby
# Copyright (c) 2011 Michael Specht
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

class CsvToMzIdentML < ProteomaticScript
    def run()
        @output.each do |ls_InPath, ls_OutPath|
            puts "Converting #{ls_InPath} to #{ls_OutPath}..."
            puts ExternalTools::binaryPath('lang.perl.perl')
        end
    end
end

script = CsvToMzIdentML.new
