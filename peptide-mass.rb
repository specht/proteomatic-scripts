# Copyright (c) 2010 Michael Specht
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
require './include/ruby/proteomics-knowledge'

class PeptideMass < ProteomaticScript
    def run()
        # collect all peptides from input files
        peptides = Set.new
        @input[:peptides].each do |path|
            peptides |= Set.new(File::read(path).split("\n"))
        end
        # now calculate all precursor m/z values
        peptides.each do |peptide|
            # start with 18 Da
            mass = elementMass('H') * 2 + elementMass('O')
            # now add mass of each amino acid
            peptide.each_char do |aa|
                mass += aminoAcidMass(aa)
            end
            (@param[:minCharge]..@param[:maxCharge]).each do |charge|
                mz = (mass + (elementMass('H') * charge)) / charge
                puts "#{sprintf('%9.4f', mz)}: #{peptide} (#{charge}+)"
            end
        end
    end
end

lk_Object = PeptideMass.new
