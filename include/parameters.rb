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
require 'include/misc'
require 'include/externaltools'


class Parameters
	def initialize()
		@mk_Parameters = Hash.new
		@mk_ParametersOrder = Array.new
	end
	
	def addParameter(ak_Parameter, as_ExtTool = '')
		if (!ak_Parameter.has_key?('key') || ak_Parameter['key'].length == 0)
			puts "Internal error: Parameter has no key."
			exit 1
		end
		if (!ak_Parameter.has_key?('type'))
			puts "Internal error: Parameter #{ak_Parameter['key']} has no type."
			exit 1
		end
		if @mk_ParametersOrder.include?(ak_Parameter['key'])
			puts "Internal error: Parameter #{ak_Parameter['key']} already exists."
			exit 1
		end
		ls_Key = ak_Parameter['key']
		@mk_ParametersOrder.push(ls_Key)
		ak_Parameter['group'] = 'Parameters' if (!ak_Parameter.has_key?('group'))
		ak_Parameter['label'] = ls_Key if (!ak_Parameter.has_key?('label'))
		lk_FallbackDefaultValue = nil
		if (ak_Parameter.has_key?('valuesFromProgram'))
			ls_Switch = ak_Parameter['valuesFromProgram']
			ls_Result = ''
			IO.popen("#{ExternalTools::binaryPath(as_ExtTool)} #{ls_Switch}") { |f| ls_Result = f.read }
			#puts ls_Result
			ak_Parameter['choices'] = Array.new
			ls_Result.each do |ls_Line|
				lk_Line = ls_Line.split(':')
				next if lk_Line.size != 2
				# check whether key is a number
				next if (lk_Line.first.strip =~ /^-?\d+$/) == nil
				ak_Parameter['choices'].push({lk_Line[0].strip => lk_Line[1].strip})
			end
		end
		if (ak_Parameter.has_key?('valuesFromConfig'))
			lk_Config = ak_Parameter['valuesFromConfig']
			ak_Parameter['choices'] = ExternalTools::getToolConfig(lk_Config['tool'])[lk_Config['key']]
		end
		case ak_Parameter['type']
		when 'bool'
			lk_FallbackDefaultValue = false
		when 'int'
			lk_FallbackDefaultValue = 0
		when 'float'
			lk_FallbackDefaultValue = 0.0
		when 'string'
			lk_FallbackDefaultValue = ''
		when 'enum'
			lk_FallbackDefaultValue = ak_Parameter['choices'].first
			lk_FallbackDefaultValue = lk_FallbackDefaultValue.keys.first if lk_FallbackDefaultValue.class == Hash
		when 'flag'
			lk_FallbackDefaultValue = false
		when 'csvString'
			lk_FallbackDefaultValue = ''
		end
		ak_Parameter['default'] = lk_FallbackDefaultValue if !ak_Parameter.has_key?('default')
		@mk_Parameters[ls_Key] = ak_Parameter
		reset(ls_Key)
	end
	
	def keys()
		return @mk_ParametersOrder
	end
	
	def value(as_Key)
		return @mk_Parameters[as_Key]['value']
	end
	
	def humanReadableValue(as_Key, as_Value)
        lk_Parameter = @mk_Parameters[as_Key]
        ls_Value = '-'
		case lk_Parameter['type']
		when 'bool'
			ls_Value = as_Value ? 'yes' : 'no'
		when 'int'
			ls_Value = as_Value.to_s
            ls_Value += " #{lk_Parameter['suffix']}" if lk_Parameter.has_key?('suffix')
		when 'float'
			ls_Value = as_Value.to_s
            ls_Value += " #{lk_Parameter['suffix']}" if lk_Parameter.has_key?('suffix')
		when 'string'
			ls_Value = as_Value
            ls_Value = '-' if ls_Value.empty?
		when 'enum'
			as_Value = as_Value.to_s unless as_Value.class == String
			@mk_Parameters[as_Key]['choices'].each do |lk_Choice|
				ls_Key = lk_Choice.class == Hash ? lk_Choice.keys.first : lk_Choice
				ls_Key = ls_Key.to_s unless ls_Key.class == String
				next unless as_Value == ls_Key
				lk_Choice = lk_Choice.values.first if lk_Choice.class == Hash
				ls_Value = lk_Choice.to_s
			end
		when 'flag'
			ls_Value = as_Value ? 'yes' : 'no'
		when 'csvString'
			as_Value = as_Value.to_s unless as_Value.class == String
			lk_Value = as_Value.split(',')
			lk_Pretty = Array.new
			lk_Value.each_index { |i| lk_Value[i].strip! }
			@mk_Parameters[as_Key]['choices'].each do |lk_Choice|
				ls_Key = lk_Choice.class == Hash ? lk_Choice.keys.first : lk_Choice
				ls_Key = ls_Key.to_s unless ls_Key.class == String
				next unless lk_Value.include?(ls_Key)
				lk_Choice = lk_Choice.values.first if lk_Choice.class == Hash
				lk_Value[lk_Value.index(ls_Key)] = lk_Choice.to_s
			end
			ls_Value = lk_Value.join(', ')
            ls_Value = '-' if ls_Value.empty?
		end

		return ls_Value
	end
	
	def default?(as_Key)
		ls_Value = @mk_Parameters[as_Key]['value']
		ls_Default = @mk_Parameters[as_Key]['default']
		ls_Value = ls_Value.to_s unless ls_Value.class == String
		ls_Default = ls_Default.to_s unless ls_Default.class == String
		ls_Value = (ls_Value == 'true' || ls_Value == 'yes') ? 'yes' : 'no' if @mk_Parameters[as_Key]['type'] == 'flag'
		return ls_Value == ls_Default
	end
	
	def parameter(as_Key)
		return @mk_Parameters[as_Key]
	end
	
	def set(as_Key, ak_Value)
		case @mk_Parameters[as_Key]['type']
		when 'float'
			@mk_Parameters[as_Key]['value'] = ak_Value.to_f
		when 'int'
			@mk_Parameters[as_Key]['value'] = ak_Value.to_i
		when 'flag'
			if (ak_Value == true || ak_Value == 'true' || ak_Value == 'yes')
				@mk_Parameters[as_Key]['value'] = true
			elsif (ak_Value == false || ak_Value == 'false' || ak_Value == 'no')
				@mk_Parameters[as_Key]['value'] = false
			else
				puts "Internal error: Invalid value for parameter #{as_Key}: #{ak_Value}."
				exit 1
			end
		else
			@mk_Parameters[as_Key]['value'] = ak_Value
		end
	end

	def reset(as_Key)
		set(as_Key, @mk_Parameters[as_Key]['default'])
	end
	
	def serialize(as_Key)
		ls_Result = ''
		ls_Result += "!!!begin parameter\n"
		@mk_Parameters[as_Key].each do |ls_Key, ls_Value|
		    if (ls_Key == 'choices')
				lk_Choices = ls_Value
				ls_Result += "!!!begin values\n"
				lk_Choices.each do |lk_Choice|
					if lk_Choice.class == Hash
						ls_Result += "#{lk_Choice.keys.first}: #{lk_Choice[lk_Choice.keys.first]}\n"
					else
						ls_Result += "#{lk_Choice}\n"
					end
				end
				ls_Result += "!!!end values\n"
			else
				ls_Result += "#{ls_Key}\n#{ls_Value}\n"
			end
		end
		ls_Result += "!!!end parameter\n"
		return ls_Result
	end
	
	def helpString()
		ls_Result = ''
		lk_Groups = Array.new
		@mk_ParametersOrder.each do |ls_Key| 
			lk_Parameter = parameter(ls_Key)
			lk_Groups.push(lk_Parameter['group']) if !lk_Groups.include?(lk_Parameter['group'])
		end
		lk_Groups.each do |ls_Group|
			# print group title
			ls_Result += "#{underline(ls_Group, '-')}\n"
			# print options
			@mk_ParametersOrder.each do |ls_Key|
				lk_Parameter = parameter(ls_Key)
				next if lk_Parameter['group'] != ls_Group
				ls_Line = "-#{ls_Key} "
				if (lk_Parameter.has_key?('choices'))
					lk_Choices = Array.new
					lk_Parameter['choices'].each do |lk_Detail|
						if lk_Detail.class == Hash
							lk_Choices.push("#{lk_Detail.keys.first}: #{lk_Detail.values.first}") if !(lk_Detail.keys.first.class == String && lk_Detail.keys.first.empty?)
						else
							lk_Choices.push(lk_Detail)
						end
					end
					ls_Line += "<#{lk_Choices.join(', ')}> (default: #{lk_Parameter['default']})"
				else
					ls_Line += "<#{lk_Parameter['type']}> (default: #{lk_Parameter['default']})"
				end
				ls_Result += "#{indent(wordwrap(ls_Line), 2, false)}\n"
				ls_Explanation = (lk_Parameter.has_key?('description') ? lk_Parameter['description'] : lk_Parameter['label'])
				ls_Explanation = indent(wordwrap(ls_Explanation), 4)
				ls_Result += "#{ls_Explanation}\n"
			end
		end
		return ls_Result
	end
	
	def parametersString()
		ls_Result = ''
		@mk_ParametersOrder.each { |ls_Key| ls_Result += serialize(ls_Key) }
		return ls_Result
	end
	
	def applyParameters(ak_Parameters)
		@mk_Parameters.each do |ls_Key, lk_Parameter|
			if (ak_Parameters.include?("-" + ls_Key))
				li_Index = ak_Parameters.index("-" + ls_Key)
				lk_Slice = ak_Parameters.slice!(li_Index, 2)
				set(ls_Key, lk_Slice[1])
			end
		end
	end
	
	def commandLineFor(as_Program)
		ls_Result = ''
		@mk_Parameters.each do |ls_Key, lk_Parameter| 
			if ls_Key.index(as_Program) == 0
				if (lk_Parameter['type'] == 'flag')
					ls_Result += " #{lk_Parameter['commandLine']}" if lk_Parameter['value']
				else
					if !(lk_Parameter['ignoreIfEmpty'] == true)
						ls_Result += " #{lk_Parameter['commandLine']} #{lk_Parameter['value']}"
 					end
				end
			end
		end
		return ls_Result
	end
end
