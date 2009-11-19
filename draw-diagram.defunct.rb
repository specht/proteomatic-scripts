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

require 'include/ruby/proteomatic'
require 'include/ruby/evaluate-omssa-helper'
require 'include/ruby/ext/fastercsv'
require 'include/ruby/misc'
require 'set'
require 'yaml'

class DrawDiagram < ProteomaticScript
	def scalex(ai_X)
		return (ai_X + 1).to_f / ($gi_ItemCount + 1) * $gi_Width + $gi_Left
	end
	
	def scaley(af_Y)
		y = af_Y + 1.0
		y = -1.0 / af_Y + 3.0 if (af_Y < 1.0)
		return (y - $gf_MinY) / ($gf_MaxY - $gf_MinY) * $gi_Height + $gi_Top
	end
	
	def run()
		lk_GroupColorsFG = ['#3465a4', '#888a85']
		lk_GroupColorsBG = ['#729fcf', '#eeeeec']
		lk_OriginalLines = Hash.new
		lk_Items = Array.new
		File.open(@input[:csvFile].first, 'r') do |lk_File|
			lk_Header = mapCsvHeader(lk_File.readline, :col_sep => ',')
			lk_File.each_line do |ls_Line|
				lk_Line = ls_Line.parse_csv(:col_sep => ',')
				lk_Item = Hash.new
				lk_Header.each_key do |x| 
					lk_Item[x] = lk_Line[lk_Header[x]]
					lk_Item[x] ||= ''
				end
				lk_Items << lk_Item
				lk_OriginalLines[lk_Item['protein']] = ls_Line
			end
		end
		
		lk_Items.collect! do |x|
			x['mean'] = '10000.0' if x['mean'] == 'Infinity'
			x
		end
		
 		lk_Items.sort! do |a, b|
			a['peptidebandcount'].to_i != b['peptidebandcount'].to_i ?
				(a['peptidebandcount'].to_i == 1 || b['peptidebandcount'].to_i == 1) ?
					b['peptidebandcount'].to_i <=> a['peptidebandcount'].to_i :
					a['mean'].to_f <=> b['mean'].to_f:
				a['mean'].to_f <=> b['mean'].to_f
					
 		end
		
		# max rel std dev is 0.6
		relstddevcutoff = 0.6
		puts lk_Items.size
		lk_Items.reject! { |x| x['rsd'].to_f > relstddevcutoff }
		puts lk_Items.size

		# min scan count is 2
		lk_Items.reject! { |x| x['scancount'].to_i < 2 }
		puts lk_Items.size

# 		File.open(@output[:diagram] + '.csv', 'w') do |lk_Out|
# 			lk_Out.puts "Protein,scan count,peptide/band/charge count,mean,stddev"
# 			lk_Items.each do |x|
# 				lk_Out.puts "\"#{x['protein']}\",#{x['scancount']},#{x['peptidebandcount']},#{x['mean']},#{x['stddev']}"
# 			end
# 		end
		
		
# 		lk_Groups = lk_Items.collect { |x| x['localization'] }.uniq.sort
# 		lk_GroupKeys = Hash.new
# 		(0...lk_Groups.size).each { |i| lk_GroupKeys[lk_Groups[i]] = i }
# 		
# 		lk_GroupStart = Array.new(lk_Groups.size)
# 		lk_GroupEnd = Array.new(lk_Groups.size)
# 		
# 		(0...lk_Items.size).each do |i|
# 			lk_GroupStart[lk_GroupKeys[lk_Items[i]['localization']]] ||= i
# 			lk_GroupEnd[lk_GroupKeys[lk_Items[i]['localization']]] = i
# 		end
		
		# this is for PBC 1 / PBC 2 or more
 		lk_Items.reject! { |x| x['peptidebandchargecount'].to_i < 2 }
		
# 		lk_Items.each do |lk_Item|
# 			puts lk_OriginalLines[lk_Item['protein']]
# 		end
		
		File.open(@output[:diagram], 'w') do |lk_Out|
			$gi_ItemCount = lk_Items.size

			$gi_Border = 16
			$gi_LeftBorder = 40
 			$gi_ImageWidth = 1200
 			$gi_ImageHeight = 660
			$gf_MinY = 7.0
			$gf_MaxY = -1.0
			$gi_TickWidth = 3.0

# 			$gi_ImageWidth = 420
# 			$gi_ImageHeight = 220
# 			$gf_MinY = 6.0
#  			$gf_MaxY = 0.0
			
			$gi_Left = $gi_LeftBorder
			$gi_Top = $gi_Border
			$gi_Width = $gi_ImageWidth - $gi_LeftBorder - $gi_Border
			$gi_Height = $gi_ImageHeight - $gi_Border * 2

			lk_Out.puts '<?xml version="1.0" encoding="utf-8"?>'
			lk_Out.puts '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">'
			lk_Out.puts "<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' xmlns:ev='http://www.w3.org/2001/xml-events' version='1.1' baseProfile='full' width='#{$gi_ImageWidth}px' height='#{$gi_ImageHeight}px'>"
			
			lk_Out.puts "<rect x='0' y='0' width='#{$gi_ImageWidth}' height='#{$gi_ImageHeight}' fill='#fff' stroke='none' />"
			
			lk_Out.puts "<rect x='#{$gi_Left}' y='#{$gi_Top}' width='#{$gi_Width}' height='#{$gi_Height}' fill='#eeeeec' stroke='#888a85' stroke-width='0.5px'/>"
			
			(1..11).each do |y|
				sy = scaley(y)
				ls_Color = '#babdb6'
				ls_Color = '#555753' if y == 1	
				lk_Out.puts "<line x1='#{$gi_Left}' y1='#{sy}' x2='#{$gi_Left + $gi_Width}' y2='#{sy}' stroke='#{ls_Color}' stroke-width='1px'/>"
				lk_Out.puts "<text x='#{$gi_Left - 4}' y='#{sy + 4}' style='font-family: Verdana; font-size: 10pt; text-anchor: end;'>#{y}</text>"
			end
			(2..4).each do |y|
				sy = scaley(1.0 / y.to_f)
				lk_Out.puts "<line x1='#{$gi_Left}' y1='#{sy}' x2='#{$gi_Left + $gi_Width}' y2='#{sy}' stroke='#babdb6' stroke-width='1px'/>"
				lk_Out.puts "<text x='#{$gi_Left - 4}' y='#{sy + 4}' style='font-family: Verdana; font-size: 10pt; text-anchor: end;'>1/#{y}</text>"
			end
			
=begin		
			(0...lk_Groups.size).each do |i|
				lk_Out.puts "<rect x='#{scalex(lk_GroupStart[i].to_f - 0.5)}' y='#{$gi_Top}' width='#{scalex(lk_GroupEnd[i] + 1) - scalex(lk_GroupStart[i])}' height='#{$gi_Height}' stroke='none' fill='#{lk_GroupColorsBG[i % lk_GroupColorsBG.size]}' opacity='0.3'/>"
				lk_Out.puts "<text x='#{scalex((lk_GroupStart[i].to_f + lk_GroupEnd[i].to_f) * 0.5)}' y='#{$gi_Top + $gi_Height - 6.0}' style='font-weight: bold; text-anchor: middle; font-family: Verdana; font-size: 10pt;'>#{lk_Groups[i]}</text>"
			end
=end

			(0...lk_Items.size).each do |i|
				lk_Item = lk_Items[i]
				#ls_Color = lk_GroupColorsFG[lk_GroupKeys[lk_Item['localization']] % lk_GroupColorsFG.size]
				ls_Color = '#888a85'
				ls_Color = '#000' if lk_Item['localization'].upcase == 'CP'
# 				li_Count = lk_Item['count'].to_i
# 				if li_Count > 100
# 					ls_Color = '#000'
# 				elsif li_Count > 20
# 					ls_Color = '#333'
# 				elsif li_Count > 0
# 					ls_Color = '#888'
# 				end
				ls_Color = '#000'
				ls_Color = '#888a85' if lk_Item['peptidebandcount'].to_i == 1
				ls_Style = ''
				#ls_Style = 'stroke-dasharray: 2, 2;' if lk_Item['marker'].include?('unknown')
				#ls_Color = '#4e9a06;' if lk_Item['localization'].upcase == 'CP-PS' 
				x = scalex(i)
				t = Hash.new
				
				t[0] = lk_Item['mean'].to_f - lk_Item['sd'].to_f
				t[1] = lk_Item['mean'].to_f
				t[2] = lk_Item['mean'].to_f + lk_Item['sd'].to_f
				if (t[1] > $gf_MinY - 1)
					t[0] = $gf_MinY - 1
					t[1] = $gf_MinY - 1
					t[2] = $gf_MinY - 1
				end
				#puts lk_Item.to_yaml if (t[2] > 7.0)
					
				lk_Out.puts "<line x1='#{x}' y1='#{scaley(t[0])}' x2='#{x}' y2='#{scaley(t[2])}' stroke='#{ls_Color}' stroke-width='1px' style='#{ls_Style}'/>"
				#[25, 50, 75].each do |k|
				[0, 1, 2].each do |k|
					#y = scaley(lk_Item["p#{k}"].to_f)
					y = scaley(t[k])
					lk_Out.puts "<line x1='#{x - $gi_TickWidth / 2.0}' y1='#{y}' x2='#{x + $gi_TickWidth / 2.0}' y2='#{y}' stroke='#{ls_Color}' stroke-width='1px'/>"
				end
 				[1].each do |k|
					#y = scaley(lk_Item["p#{k}"].to_f)
					y = scaley(t[k])
# 					if lk_Item['marker'].include?('unknown')
# 						stroke = ls_Color
# 						fill = '#eeeeec'
# 					end
					stroke = 'none'
					fill = ls_Color
					if lk_Item['method'] == 'AMT'
						fill = '#ffffff'
						stroke = ls_Color
					end
					lk_Out.puts "<circle cx='#{x}' cy='#{y}' r='1.8' stroke='#{stroke}' fill='#{fill}'/>"
					#lk_Out.puts "<circle cx='#{x}' cy='#{y}' r='2.0' stroke='none' fill='#000'/>"
 				end
			end
			
			
			lk_Out.puts '</svg>'
		end
		
		exit
	end
end

lk_Object = DrawDiagram.new
