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

require 'rexml/document'
require 'rexml/streamlistener'
require 'base64'


KA BLAM!! In Soviet Russia, peptide searches YOU!!


class SpectrumXmlParserMzData
	include REXML::StreamListener
	
	def initialize(ak_Proc, ak_Options = {:levels => (1..10).to_a})
		@mk_CurrentSpectrum = Hash.new
		@mk_XmlPath = Array.new
		@mk_Treat = Hash.new()
		@mk_Treat['32-little'] = 'e';
		@mk_Treat['64-little'] = 'E';
		@mk_Treat['32-big'] = 'g';
		@mk_Treat['64-big'] = 'G';
		@ms_ExperimentName = 'untitled';
		@mk_Proc = ak_Proc
		@mk_Options = ak_Options
	end
	
	def tag_start(as_Name, ak_Attributes)
		lk_Hash = Hash.new()
		lk_Hash['tag'] = as_Name
		lk_Hash['attributes'] = ak_Attributes
		if (as_Name == 'spectrum')
			@mk_CurrentSpectrum = Hash.new 
			@mk_CurrentSpectrum['id'] = ak_Attributes['id']
		end
		@mk_XmlPath.push(lk_Hash)
		if (@mk_XmlPath.size > 1 && @mk_XmlPath[@mk_XmlPath.size - 2]['tag'] == 'ionSelection' && as_Name == 'cvParam')
			ls_Key = ak_Attributes['name'] == 'ChargeState' ? 'charge' : 'mz'
			if (ls_Key == 'mz')
				lk_Value = ak_Attributes['name'] == 'ChargeState' ? ak_Attributes['value'].to_i : ak_Attributes['value'].to_f 
				@mk_CurrentSpectrum[ls_Key] = lk_Value
			else
				@mk_CurrentSpectrum[ls_Key] = Array.new if !@mk_CurrentSpectrum.has_key?(ls_Key)
				lk_Value = ak_Attributes['name'] == 'ChargeState' ? ak_Attributes['value'].to_i : ak_Attributes['value'].to_f 
				@mk_CurrentSpectrum[ls_Key].push(lk_Value)
			end
		end
	end
	
	def text(as_Text)
		ls_Second = ''
		ls_First = ''
		if (@mk_XmlPath.size >= 2)
			ls_Second = @mk_XmlPath[@mk_XmlPath.size - 2]['tag']
			ls_First = @mk_XmlPath[@mk_XmlPath.size - 1]['tag']
		end
		if (ls_First == 'data' && (ls_Second == 'mzArrayBinary' || ls_Second == 'intenArrayBinary'))
			ls_Decoded = Base64.decode64(as_Text)
			li_Length = @mk_XmlPath.last['attributes']['length'].to_i
			ls_Treat = @mk_Treat[@mk_XmlPath.last['attributes']['precision'] + '-' + @mk_XmlPath.last['attributes']['endian']]
			ls_Code = ''
			(0...li_Length).each { |i| ls_Code += ls_Treat }
			lk_Values = ls_Decoded.unpack(ls_Code)
			ls_Key = ls_Second == 'intenArrayBinary' ? 'intensityList' : 'mzList'
			@mk_CurrentSpectrum[ls_Key] = lk_Values
			#puts lk_Values.to_yaml
		end
		@ms_ExperimentName = as_Text.gsub('.RAW', '').gsub('file://', '') if (ls_First == 'nameOfFile' && ls_Second == 'sourceFile')
		@mk_CurrentSpectrum['experimentName'] = @ms_ExperimentName
	end
	
	def tag_end(as_Name)
		@mk_Proc.call(@mk_CurrentSpectrum) if (as_Name == 'spectrum')
		@mk_XmlPath.pop()
	end
end


class SpectrumXmlParserMzXml
	include REXML::StreamListener
	
	def initialize(ak_Proc, ak_Options = {:levels => (1..10).to_a})
		@mk_CurrentSpectrumStack = Array.new
		@mk_XmlPath = Array.new
		@mk_Treat = Hash.new()
		@mk_Treat['32-little'] = 'e';
		@mk_Treat['64-little'] = 'E';
		@mk_Treat['32-network'] = 'g';
		@mk_Treat['64-network'] = 'G';
		@ms_ExperimentName = 'untitled';
		@mk_Proc = ak_Proc
		@mk_Options = ak_Options
	end
	
	def tag(ai_Index)
		return @mk_XmlPath.size > ai_Index ? @mk_XmlPath[@mk_XmlPath.size - 1 - ai_Index]['tag'] : ''
	end
	
	def attributes(ai_Index)
		return @mk_XmlPath.size > ai_Index ? @mk_XmlPath[@mk_XmlPath.size - 1 - ai_Index]['attributes'] : Hash.new()
	end
	
	def tag_start(as_Name, ak_Attributes)
		lk_Hash = Hash.new()
		lk_Hash['tag'] = as_Name
		lk_Hash['attributes'] = ak_Attributes
		@mk_XmlPath.push(lk_Hash)
		if (as_Name == 'scan')
			@mk_CurrentSpectrumStack.push(Hash.new)
			@mk_CurrentSpectrumStack.last['id'] = ak_Attributes['num']
			@mk_CurrentSpectrumStack.last['level'] = ak_Attributes['msLevel'].to_i
			@mk_CurrentSpectrumStack.last['time'] = ak_Attributes['retentionTime']
			@mk_CurrentSpectrumStack.last['experimentName'] = @ms_ExperimentName
		end
		if (tag(0) == 'parentFile' && tag(1) == 'msRun')
			@ms_ExperimentName = File::basename(ak_Attributes['fileName'].gsub('.RAW', '').gsub('file://', ''))
		end
	end
	
	def text(as_Text)
		if (tag(0) == 'precursorMz' && tag(1) == 'scan')
			@mk_CurrentSpectrumStack.last['mz'] = as_Text.to_f
		end
		if (tag(0) == 'peaks' && tag(1) == 'scan')
			ls_Decoded = Base64.decode64(as_Text)
			li_Length = @mk_XmlPath[@mk_XmlPath.size - 2]['attributes']['peaksCount'].to_i * 2
			ls_Treat = @mk_Treat[@mk_XmlPath.last['attributes']['precision'] + '-' + @mk_XmlPath.last['attributes']['byteOrder']]
			ls_Code = ''
			(0...li_Length).each { |i| ls_Code += ls_Treat }
			lk_Values = ls_Decoded.unpack(ls_Code)
			@mk_CurrentSpectrumStack.last['mzList'] = Array.new
			@mk_CurrentSpectrumStack.last['intensityList'] = Array.new
			lk_Id = ['mzList', 'intensityList']
			lk_Values.each_index do |li_Index|
				ls_Id = lk_Id[li_Index % 2]
				@mk_CurrentSpectrumStack.last[ls_Id].push(lk_Values[li_Index])
			end
		end
		
	end
	
	def tag_end(as_Name)
		if as_Name == 'scan'
			if (@mk_Options[:levels].include?(@mk_CurrentSpectrumStack.last['level']))
				@mk_Proc.call(@mk_CurrentSpectrumStack.last)
			end
			@mk_CurrentSpectrumStack.pop
		end
		@mk_XmlPath.pop()
	end
end


class SpectrumIterator
	def initialize(as_Filename, ak_Proc, ak_Options = {:levels => (1..10).to_a})
		@ms_Filename = as_Filename
		@mk_Proc = ak_Proc
		@mk_Options = ak_Options
	end
	
	def run
		lk_File = File.new(@ms_Filename)
		if fileMatchesFormat(@ms_Filename, 'xml-mzdata')
			REXML::Document.parse_stream(lk_File, SpectrumXmlParserMzData.new(@mk_Proc, @mk_Options))
		elsif fileMatchesFormat(@ms_Filename, 'xml-mzxml')
			REXML::Document.parse_stream(lk_File, SpectrumXmlParserMzXml.new(@mk_Proc, @mk_Options))
		elsif fileMatchesFormat(@ms_Filename, 'dta')
			@mk_CurrentSpectrum = Hash.new 
			lk_Temp = @ms_Filename.gsub('.dta', '').split('.')
			if (lk_Temp.size < 2)
				puts "Error reading #{@ms_Filename}"
				puts lk_Temp.to_yaml
				return
			end
			@mk_CurrentSpectrum['id'] = lk_Temp[lk_Temp.size - 2].to_s
			lk_Line = lk_File.readline.split(' ')
			if (lk_Line.size != 2)
				puts "Error reading #{@ms_Filename}"
				puts lk_Line.to_yaml
				return
			end
			li_Charge = lk_Line[1].strip.to_i
			lf_PrecursorMH = lk_Line[0].strip.to_f
			lf_Mz = (lf_PrecursorMH + 1.007825 * (li_Charge - 1)) / li_Charge
			@ms_ExperimentName = File::basename(@ms_Filename)
			@ms_ExperimentName = @ms_ExperimentName[0, @ms_ExperimentName.index('.')]
			@mk_CurrentSpectrum['charge'] = Array.new
			@mk_CurrentSpectrum['charge'].push(li_Charge)
			@mk_CurrentSpectrum['mz'] = lf_Mz
			@mk_CurrentSpectrum['mzList'] = Array.new
			@mk_CurrentSpectrum['intensityList'] = Array.new
			while (!lk_File.eof())
				ls_Line = lk_File.readline
				lk_Line = ls_Line.split(' ')
				if (lk_Line.size == 2)
					@mk_CurrentSpectrum['mzList'].push(lk_Line[0].strip.to_f)
					@mk_CurrentSpectrum['intensityList'].push(lk_Line[1].strip.to_f)
				end
			end
			@mk_Proc.call(@mk_CurrentSpectrum) if (ak_Options[:levels].include?(2))
			lk_File.close()
		elsif fileMatchesFormat(@ms_Filename, 'mgf')
			puts 'TODO: MGF parsing not yet implemented.'
			exit 1
=begin
			@mk_CurrentSpectrum = Hash.new 
			lk_Temp = @ms_Filename.gsub('.mgf', '').split('.')
			if (lk_Temp.size < 2)
				puts "Error reading #{@ms_Filename}"
				puts lk_Temp.to_yaml
				return
			end
			@mk_CurrentSpectrum['id'] = lk_Temp[lk_Temp.size - 2].to_s
			lk_Line = lk_File.readline.split(' ')
			if (lk_Line.size != 2)
				puts "Error reading #{@ms_Filename}"
				puts lk_Line.to_yaml
				return
			end
			li_Charge = lk_Line[1].strip.to_i
			lf_PrecursorMH = lk_Line[0].strip.to_f
			lf_Mz = (lf_PrecursorMH + 1.007825 * (li_Charge - 1)) / li_Charge
			@ms_ExperimentName = File::basename(@ms_Filename)
			@ms_ExperimentName = @ms_ExperimentName[0, @ms_ExperimentName.index('.')]
			@mk_CurrentSpectrum['charge'] = Array.new
			@mk_CurrentSpectrum['charge'].push(li_Charge)
			@mk_CurrentSpectrum['mz'] = lf_Mz
			@mk_CurrentSpectrum['mzList'] = Array.new
			@mk_CurrentSpectrum['intensityList'] = Array.new
			while (!lk_File.eof())
				ls_Line = lk_File.readline
				lk_Line = ls_Line.split(' ')
				if (lk_Line.size == 2)
					@mk_CurrentSpectrum['mzList'].push(lk_Line[0].strip.to_f)
					@mk_CurrentSpectrum['intensityList'].push(lk_Line[1].strip.to_f)
				end
			end
			@mk_Proc.call(@mk_CurrentSpectrum)
			lk_File.close()
=end
		end
	end
end


class DtaIterator < SpectrumIterator
	def initialize(as_Filename, ak_Proc, ak_Options = {:levels => (1..10).to_a, :iterateAllCharges => true})
		@mb_IterateAllCharges = ak_Options[:iterateAllCharges]
		@mk_ChildProc = ak_Proc
		@mk_SpectrumProc = Proc.new do |ak_Spectrum|
			unless @mb_IterateAllCharges
				# strip all but first charge from charge array if desired
				ak_Spectrum['charge'] = [ak_Spectrum['charge'].first] unless ak_Spectrum['charge'].empty?
			end
			ak_Spectrum['charge'].each do |li_Charge|
				ls_DtaFilename = "#{ak_Spectrum['experimentName']}.#{ak_Spectrum['id']}.#{ak_Spectrum['id']}.#{li_Charge}.dta"
				ls_Result = ''
				lf_PrecursorMH = (ak_Spectrum['mz'] * li_Charge) - 1.007825 * (li_Charge - 1)
				ls_Result += sprintf("%0.6f %d\n", lf_PrecursorMH, li_Charge)
				(0...ak_Spectrum['mzList'].size).each { |i| ls_Result += sprintf("%0.6f %0.6f\n", ak_Spectrum['mzList'][i], ak_Spectrum['intensityList'][i]) }
				@mk_ChildProc.call(ls_DtaFilename, ls_Result)
			end
		end
		super(as_Filename, @mk_SpectrumProc, ak_Options)
	end
end


class MgfIterator < SpectrumIterator
	def initialize(as_Filename, ak_Proc, ak_Options = {:levels => (1..10).to_a, :iterateAllCharges => true})
		@mb_IterateAllCharges = ak_Options[:iterateAllCharges]
		@mk_ChildProc = ak_Proc
		@mk_SpectrumProc = Proc.new do |ak_Spectrum|
			if (ak_Spectrum.has_key?('charge') && !ak_Spectrum['charge'].empty?)
				unless @mb_IterateAllCharges
					# strip all but first charge from charge array if desired
					ak_Spectrum['charge'] = [ak_Spectrum['charge'].first] unless ak_Spectrum['charge'].empty?
				end
				ak_Spectrum['charge'].each do |li_Charge|
					ls_DtaFilename = "#{ak_Spectrum['experimentName']}.#{ak_Spectrum['id']}.#{ak_Spectrum['id']}.#{li_Charge}.dta"
					ls_Result = ''
					ls_Result += "BEGIN IONS\n"
					ls_Result += sprintf "TITLE=#{ls_DtaFilename}\n"
					ls_Result += sprintf "PEPMASS=%0.6f\n", ak_Spectrum['mz']
					ls_Result += sprintf "CHARGE=#{li_Charge}+\n"
					(0...ak_Spectrum['mzList'].size).each { |i| ls_Result += sprintf "%0.6f %0.6f\n", ak_Spectrum['mzList'][i], ak_Spectrum['intensityList'][i] }
					ls_Result += "END IONS\n\n"
					@mk_ChildProc.call(ls_Result)
				end
			else
				ls_DtaFilename = "#{ak_Spectrum['experimentName']}.#{ak_Spectrum['id']}.#{ak_Spectrum['id']}.dta"
				ls_Result = ''
				ls_Result += "BEGIN IONS\n"
				ls_Result += sprintf "TITLE=#{ls_DtaFilename}\n"
				ls_Result += sprintf "PEPMASS=%0.6f\n", ak_Spectrum['mz']
				(0...ak_Spectrum['mzList'].size).each { |i| ls_Result += sprintf "%0.6f %0.6f\n", ak_Spectrum['mzList'][i], ak_Spectrum['intensityList'][i] }
				ls_Result += "END IONS\n\n"
				@mk_ChildProc.call(ls_Result)
			end
		end
		super(as_Filename, @mk_SpectrumProc, ak_Options)
	end
end
