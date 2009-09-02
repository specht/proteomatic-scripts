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

require 'include/proteomatic'

class RunMascot < ProteomaticScript
	def run()
		puts "Hello, this is the MASCOT script. MC is set to #{@param[:PFA]}."
		ls_Config = DATA.read
		ls_Config.sub!('#{PFA}', @param[:PFA].to_s)
		@ms_TempPath = tempFilename('run-mascot')
		FileUtils::mkpath(@ms_TempPath)
		ls_ConfigPath = File::join(@ms_TempPath, 'config.xml')
		ls_OutPath = File::join(@ms_TempPath, 'out.pep.xml')
		File::open(ls_ConfigPath, 'w') do |f|
			f.puts ls_Config
		end
		ls_Command = "\"#{ExternalTools::binaryPath('promass.LALALALALALAQ!!!!!!!searchadapter').gsub('/', '\\')}\" -M -p:\"#{ls_ConfigPath.gsub('/', '\\')}\" -i:\"#{@input[:spectra].join(' ').gsub('/', '\\')}\" -f:\"#{ls_OutPath.gsub('/', '\\')}\" -mz:\"#{@input[:spectraXml].join(' ').gsub('/', '\\')}\""
		puts ls_Command
		system(ls_Command)
		FileUtils::mv(ls_OutPath, @output[:resultFile])
	end
end

lk_Object = RunMascot.new


__END__
<?xml version="1.0"?>
<ArrayOfParamter xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <Paramter Name="Service name" Parameter="COM" Value="TPPService" Use="true" />
  <Paramter Name="Name of user" Parameter="USERNAME" Value="TPP" Use="true" />
  <Paramter Name="" Parameter="SEG" Value=" " Use="true" />
  <Paramter Name="Missed cleavages" Parameter="PFA" Value="#{PFA}" Use="true" />
  <Paramter Name="" Parameter="REPORT" Value="2000" Use="true" />
  <Paramter Name="" Parameter="FORMAT" Value="Mascot generic" Use="true" />
  <Paramter Name="" Parameter="FORMVER" Value="1.01" Use="true" /> 
  <Paramter Name="" Parameter="OVERVIEW" Value="OFF" Use="true" />
  <Paramter Name="Mass type" Parameter="MASS" Value="Monoisotopic" Use="true" />
  <Paramter Name="Precursor mass tol (ppm)" Parameter="TOL" Value="10" Use="true" />
  <Paramter Name="Precursor mass tol unit" Parameter="TOLU" Value="ppm" Use="true" />
  <Paramter Name="Product mass tol (Da)" Parameter="ITOL" Value="0.8" Use="true" />
  <Paramter Name="Product mass tol unit" Parameter="ITOLU" Value="Da" Use="true" />
  <Paramter Name="Max Charge" Parameter="CHARGE" Value="4+" Use="true" />
  <Paramter Name="Database" Parameter="DB" Value="Chlre_3_1" Use="true" />
  <Paramter Name="DatabaseFile" Parameter="DB" Value="D:\mascot\mascot_db\Chlamydomonas\current\Chlre3_1.GeneCatalog_2007_09_13.mt.cp.withNames.Cons.plusShuffled.fasta" Use="false" />
  <Paramter Name="Taxonomy" Parameter="TAXONOMY" Value="All entries" Use="true" />
  <Paramter Name="Enzyme" Parameter="CLE" Value="trypsin" Use="true" />
  <Paramter Name="" Parameter="SEARCH" Value="MIS" Use="true" />
  <Paramter Name="Instrument" Parameter="INSTRUMENT" Value="ESI-TRAP" Use="true" />	
  <Paramter Name="Fixed Mods" Parameter="MODS" Value=" " Use="true" />
  <Paramter Name="Variable Mods" Parameter="IT_MODS" Value="Carbamidomethyl (C),Oxidation (M)" Use="true" />
</ArrayOfParamter>