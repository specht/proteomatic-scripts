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
require 'include/fastercsv'
require 'include/misc'
require 'bigdecimal'
require 'set'
require 'yaml'

=begin
plot estimated fpr vs. score threshold (target/decoy only)
plot score histogram
plot mass accuracy histogram
=end

class AnalyzePsm < ProteomaticScript
	def drawHistogram(ak_Out, ak_Parameters)
	end
	
	def scale(af_Value, af_Min, af_Max)
		return (af_Value - af_Min) / (af_Max - af_Min) * (@mi_ClientWidth - 20) + 10
	end
	
	def scaley(af_Value, af_Min, af_Max)
		return (af_Value - af_Min) / (af_Max - af_Min) * (@mi_ClientHeight - 20) + 10
	end
	
	def run()
		if @output[:psmAnalysis]
			File.open(@output[:psmAnalysis], 'w') do |lk_Out|
				lk_Out.puts "<?xml version='1.0' encoding='utf-8' ?>"
				lk_Out.puts "<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.1//EN' 'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd'>"
				lk_Out.puts "<html xmlns='http://www.w3.org/1999/xhtml' xml:lang='de'>"
				lk_Out.puts '<head>'
				lk_Out.puts '<title>PSM Analysis</title>'
				printStyleSheet(lk_Out)
				lk_Out.puts '</head>'
				lk_Out.puts '<body>'
				lk_Out.puts "<h1>PSM Analysis</h1>"
				@input[:omssaResults].each do |ls_Path|
					lk_Out.puts "<h2>#{File.basename(ls_Path)}</h2>"
					print "#{File.basename(ls_Path)}: "
					lk_ScanHash = Hash.new
					ld_ScoreMinimum = BigDecimal.new("1.0")
					ld_ScoreMaximum = BigDecimal.new("0.0")
					ld_PpmMaximum = 0.0
					File.open(ls_Path) do |lk_File|
						lk_Header = mapCsvHeader(lk_File.readline)
						lk_File.each_line do |ls_Line|
							lk_Line = ls_Line.parse_csv
							ls_ScanId = lk_Line[lk_Header['spectrumnumber']]
							lf_Mass = lk_Line[lk_Header['mass']].to_f
							lf_TheoMass = lk_Line[lk_Header['theomass']].to_f
							lf_Ppm = ((lf_Mass - lf_TheoMass).abs / lf_Mass) * 1000000.0
							lk_Psm = {
								:peptide => lk_Line[lk_Header['peptide']], 
								:score => BigDecimal.new(lk_Line[lk_Header['evalue']]),
								:ppm => lf_Ppm,
								:decoy => (lk_Line[lk_Header['defline']].index('decoy_') == 0)
							}
							if (lk_ScanHash.include?(ls_ScanId))
								lk_ScanHash[ls_ScanId] = lk_Psm if (lk_Psm[:score] < lk_ScanHash[ls_ScanId][:score])
							else
								lk_ScanHash[ls_ScanId] = lk_Psm
							end
							ld_ScoreMinimum = lk_Psm[:score] if lk_Psm[:score] < ld_ScoreMinimum
							ld_ScoreMaximum = lk_Psm[:score] if lk_Psm[:score] > ld_ScoreMaximum
							ld_PpmMaximum = lf_Ppm if lf_Ppm > ld_PpmMaximum
						end
					end
					puts "#{lk_ScanHash.size} PSM."
					ld_ScaleMinimum = Math.log10(ld_ScoreMinimum).floor

					@mi_Width = 800
					@mi_Height = 400
					@mi_Left = 35.0
					@mi_Top = 0.0
					@mi_Right = 0.0
					@mi_Bottom = 20.0
					@mi_ClientWidth = @mi_Width.to_f - @mi_Left - @mi_Right
					@mi_ClientHeight = @mi_Height.to_f - @mi_Top - @mi_Bottom

					lk_Out.puts "<h3>Score histogram</h3>"
					
					lk_Histogram = Array.new
					@mi_ClientWidth.to_i.times { lk_Histogram << 0 }
					li_HistogramMax = 0
					lk_ScanHash.each do |ls_Key, lk_Psm|
						ld_Scale = Math.log10(lk_Psm[:score])
						li_Bucket = scale(ld_Scale, ld_ScaleMinimum, 0.0).to_i
						li_Bucket = 0 if li_Bucket < 0
						li_Bucket = @mi_ClientWidth - 1 if li_Bucket > @mi_ClientWidth - 1
						lk_Histogram[li_Bucket] += 1
						li_HistogramMax = lk_Histogram[li_Bucket] if lk_Histogram[li_Bucket] > li_HistogramMax
					end
					lk_Out.puts "<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' xmlns:ev='http://www.w3.org/2001/xml-events' version='1.1' baseProfile='full' width='#{@mi_Width}px' height='#{@mi_Height}px'><rect x='0' y='0' width='#{@mi_Width}px' height='#{@mi_Height}px' fill='#fff' />"
					lk_Out.puts "<rect x='#{@mi_Left}' y='#{@mi_Top}' width='#{@mi_ClientWidth}' height='#{@mi_ClientHeight}' stroke='#888a85' fill='#eeeeec' />"
					lk_Out.print "<polyline points='"
					lk_Out.print "#{@mi_Left} #{@mi_Height - @mi_Bottom} "
					(0...@mi_ClientWidth - 1).each do |i|
						lk_Out.print "#{i + @mi_Left} #{@mi_Height - @mi_Bottom - (lk_Histogram[i].to_f / li_HistogramMax) * @mi_ClientHeight} "
					end
					lk_Out.print "#{@mi_Left + @mi_ClientWidth - 1} #{@mi_Height - @mi_Bottom} "
					lk_Out.puts "' fill='#729fcf' stroke='none' stroke-width='0.75px'/>"
					
					# draw lower legend
					ld_ScaleStart = ld_ScaleMinimum
					ld_ScaleEnd = 1.0
					li_CurrentScale = 0
					li_ScaleSkip = 1
					ld_Distance = 0.0
					begin
						ld_Distance = (scale(li_CurrentScale, ld_ScaleMinimum, 0.0) - 
							scale(li_CurrentScale - li_ScaleSkip, ld_ScaleMinimum, 0.0)).abs
						break unless ld_Distance < 32.0
						li_ScaleSkip += 1
					end while ld_Distance < 32.0
					while (li_CurrentScale >= ld_ScaleMinimum)
						x = scale(li_CurrentScale, ld_ScaleMinimum, 0.0) + @mi_Left
						ls_Label = li_CurrentScale == 0 ? '1.0' : "1e#{li_CurrentScale}"
						lk_Out.puts "<polyline points='#{x} #{@mi_Height - @mi_Bottom} #{x} #{@mi_Height - @mi_Bottom + 4.0}' stroke='#555753' stroke-width='1.0px' />"
						lk_Out.puts "<text x='#{x}' y='#{@mi_Height - @mi_Bottom + 12}' style='font-size: 6pt; text-anchor: middle;'>#{ls_Label}</text>"
						li_CurrentScale -= li_ScaleSkip
					end
					
					# draw left legend
					li_CurrentScale = 0
					lk_ScaleSkips = [1, 2, 5]
					li_ScaleSkipIndex = 0
					li_ScaleExponent = 0
					ld_Distance = 0.0

					begin
						li_ScaleSkip = lk_ScaleSkips[li_ScaleSkipIndex] * (10 ** li_ScaleExponent)
						ld_Distance = (((li_CurrentScale.to_f / li_HistogramMax) * @mi_ClientHeight) - 
							(((li_CurrentScale + li_ScaleSkip).to_f / li_HistogramMax) * @mi_ClientHeight)).abs
						
						break unless ld_Distance < 16.0
						li_ScaleSkipIndex += 1
						if (li_ScaleSkipIndex > lk_ScaleSkips.size - 1)
							li_ScaleSkipIndex = 0
							li_ScaleExponent += 1
						end
					end while ld_Distance < 16.0

					li_ScaleSkip = lk_ScaleSkips[li_ScaleSkipIndex] * (10 ** li_ScaleExponent)
					while (li_CurrentScale <= li_HistogramMax)
						ld_Position = @mi_Height.to_f - @mi_Bottom - (li_CurrentScale.to_f / li_HistogramMax) * @mi_ClientHeight
						ls_Label = "#{li_CurrentScale}"
						lk_Out.puts "<polyline points='#{@mi_Left - 4} #{ld_Position} #{@mi_Left} #{ld_Position}' stroke='#555753' stroke-width='1.0px' />"
						lk_Out.puts "<text x='#{@mi_Left - 6}' y='#{ld_Position + 4}' style='font-size: 6pt; text-anchor: end;'>#{ls_Label}</text>"
						li_CurrentScale += li_ScaleSkip
					end
					lk_Out.puts "</svg>"
					
					lk_Out.puts "<h3>Mass accuracy histogram</h3>"
					
					lk_Histogram = Array.new
					@mi_ClientWidth.to_i.times { lk_Histogram << 0 }
					lk_ScanHash.each do |ls_Key, lk_Psm|
						li_Bucket = scale(lk_Psm[:ppm], 0.0, ld_PpmMaximum).to_i
						li_Bucket = 0 if li_Bucket < 0
						li_Bucket = @mi_ClientWidth - 1 if li_Bucket > @mi_ClientWidth - 1
						lk_Histogram[li_Bucket] += 1
						li_HistogramMax = lk_Histogram[li_Bucket] if lk_Histogram[li_Bucket] > li_HistogramMax
					end
					lk_Out.puts "<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' xmlns:ev='http://www.w3.org/2001/xml-events' version='1.1' baseProfile='full' width='#{@mi_Width}px' height='#{@mi_Height}px'><rect x='0' y='0' width='#{@mi_Width}px' height='#{@mi_Height}px' fill='#fff' />"
					lk_Out.puts "<rect x='#{@mi_Left}' y='#{@mi_Top}' width='#{@mi_ClientWidth}' height='#{@mi_ClientHeight}' stroke='#888a85' fill='#eeeeec' />"
					lk_Out.print "<polyline points='"
					lk_Out.print "#{@mi_Left} #{@mi_Height - @mi_Bottom} "
					(0...@mi_ClientWidth).each do |i|
						lk_Out.print "#{i + @mi_Left} #{@mi_Height - @mi_Bottom - ((lk_Histogram[i].to_f / li_HistogramMax)) * @mi_ClientHeight} "
					end
					lk_Out.print "#{@mi_ClientWidth + @mi_Left} #{@mi_Height - @mi_Bottom} "
					lk_Out.puts "' fill='#729fcf' stroke='none' stroke-width='0.75px'/>"
					
					# draw lower legend
					li_CurrentScale = 0.0
					lk_ScaleSkips = [1, 2, 5]
					li_ScaleSkipIndex = 0
					li_ScaleExponent = -2
					ld_Distance = 0.0

					begin
						li_ScaleSkip = lk_ScaleSkips[li_ScaleSkipIndex] * (10 ** li_ScaleExponent)
						ld_Distance = (scale(li_CurrentScale, 0.0, ld_PpmMaximum) - 
							scale(li_CurrentScale + li_ScaleSkip, 0.0, ld_PpmMaximum)).abs
						
						break unless ld_Distance < 32.0
						li_ScaleSkipIndex += 1
						if (li_ScaleSkipIndex > lk_ScaleSkips.size - 1)
							li_ScaleSkipIndex = 0
							li_ScaleExponent += 1
						end
					end while ld_Distance < 32.0

					li_ScaleSkip = lk_ScaleSkips[li_ScaleSkipIndex] * (10 ** li_ScaleExponent)
					while (li_CurrentScale <= ld_PpmMaximum)
						ld_Position = scale(li_CurrentScale, 0.0, ld_PpmMaximum) + @mi_Left
						ls_Label = "#{li_CurrentScale}"
						lk_Out.puts "<polyline points='#{ld_Position} #{@mi_Height - @mi_Bottom} #{ld_Position} #{@mi_Height - @mi_Bottom + 4.0}' stroke='#555753' stroke-width='1.0px' />"
						lk_Out.puts "<text x='#{ld_Position}' y='#{@mi_Height - @mi_Bottom + 12}' style='font-size: 6pt; text-anchor: middle;'>#{ls_Label}</text>"
						li_CurrentScale += li_ScaleSkip
					end
					
					# draw left legend
					li_CurrentScale = 0
					lk_ScaleSkips = [1, 2, 5]
					li_ScaleSkipIndex = 0
					li_ScaleExponent = 0
					ld_Distance = 0.0

					begin
						li_ScaleSkip = lk_ScaleSkips[li_ScaleSkipIndex] * (10 ** li_ScaleExponent)
						ld_Distance = (((li_CurrentScale.to_f / li_HistogramMax) * @mi_ClientHeight) - 
							(((li_CurrentScale + li_ScaleSkip).to_f / li_HistogramMax) * @mi_ClientHeight)).abs
						
						break unless ld_Distance < 16.0
						li_ScaleSkipIndex += 1
						if (li_ScaleSkipIndex > lk_ScaleSkips.size - 1)
							li_ScaleSkipIndex = 0
							li_ScaleExponent += 1
						end
					end while ld_Distance < 16.0

					li_ScaleSkip = lk_ScaleSkips[li_ScaleSkipIndex] * (10 ** li_ScaleExponent)
					while (li_CurrentScale <= li_HistogramMax)
						ld_Position = @mi_Height.to_f - @mi_Bottom - (li_CurrentScale.to_f / li_HistogramMax) * @mi_ClientHeight
						ls_Label = "#{li_CurrentScale}"
						lk_Out.puts "<polyline points='#{@mi_Left - 4} #{ld_Position} #{@mi_Left} #{ld_Position}' stroke='#555753' stroke-width='1.0px' />"
						lk_Out.puts "<text x='#{@mi_Left - 6}' y='#{ld_Position + 4}' style='font-size: 6pt; text-anchor: end;'>#{ls_Label}</text>"
						li_CurrentScale += li_ScaleSkip
					end
					
					lk_Out.puts "</svg>"

					@mi_Left = 35.0
					@mi_Top = 20.0
					@mi_Right = 35.0
					@mi_Bottom = 20.0
					@mi_ClientWidth = @mi_Width.to_f - @mi_Left - @mi_Right
					@mi_ClientHeight = @mi_Height.to_f - @mi_Top - @mi_Bottom

					lk_Out.puts "<h3>FPR plot</h3>"
					
					lk_SortedByScore = lk_ScanHash.keys.sort { |a, b| lk_ScanHash[a][:score] <=> lk_ScanHash[b][:score] }
					lk_Histogram = Array.new
					
					lf_LogScale = 0.4
					li_TotalCount = 0
					li_DecoyCount = 0
					lk_SortedByScore.each do |ls_Key|
						lk_Psm = lk_ScanHash[ls_Key]
						li_TotalCount += 1
						li_DecoyCount += 1 if lk_Psm[:decoy]
						lf_Fpr = li_DecoyCount.to_f * 2.0 / li_TotalCount.to_f
						lf_Fpr *= 0.5
						lk_Histogram << {:fpr => lf_Fpr, :score => lk_Psm[:score], :decoyCount => li_DecoyCount.to_f / lk_SortedByScore.size, :targetCount => (li_TotalCount - li_DecoyCount).to_f / lk_SortedByScore.size }
					end
					
					lk_Out.puts "<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' xmlns:ev='http://www.w3.org/2001/xml-events' version='1.1' baseProfile='full' width='#{@mi_Width}px' height='#{@mi_Height}px'><rect x='0' y='0' width='#{@mi_Width}px' height='#{@mi_Height}px' fill='#fff' />"

					li_Shift = 0
 					lk_Out.puts "<polyline points='#{@mi_Left} 8 #{@mi_Left + 16} 8' fill='none' stroke='#729fcf' stroke-width='1.5px' />"
					lk_Out.puts "<text x='#{@mi_Left + 20}' y='12' style='font-size: 8pt;'>estimated FPR</text>"
					li_Shift += 110
 					lk_Out.puts "<polyline points='#{@mi_Left + li_Shift} 8 #{@mi_Left + 16 + li_Shift} 8' fill='none' stroke='#8ae234' stroke-width='1.5px' />"
					lk_Out.puts "<text x='#{@mi_Left + 20 + li_Shift}' y='12' style='font-size: 8pt;'>score</text>"
					li_Shift += 65
 					lk_Out.puts "<rect x='#{@mi_Left + li_Shift}' y='5' width='16' height='6' fill='#8ae234' fill-opacity='0.3' stroke='#73d216' stroke-width='0.75px' />"
					lk_Out.puts "<text x='#{@mi_Left + 20 + li_Shift}' y='12' style='font-size: 8pt;'>target hits</text>"
					li_Shift += 90
 					lk_Out.puts "<rect x='#{@mi_Left + li_Shift}' y='5' width='16' height='6' fill='#ef2929' fill-opacity='0.3' stroke='#cc0000' stroke-width='0.75px' />"
					lk_Out.puts "<text x='#{@mi_Left + 20 + li_Shift}' y='12' style='font-size: 8pt;'>decoy hits</text>"
					
					lk_Out.puts "<rect x='#{@mi_Left}' y='#{@mi_Top}' width='#{@mi_ClientWidth}' height='#{@mi_ClientHeight}' stroke='#888a85' fill='#eeeeec' />"

					# draw target background triangle
					lk_Out.print "<polyline points='"
					lk_Out.print "#{@mi_Left} #{@mi_Height - @mi_Bottom} "
					lk_Out.print "#{@mi_Width - @mi_Right} #{@mi_Height - @mi_Bottom} "
					lk_Out.print "#{@mi_Width - @mi_Right} #{@mi_Top} "
					lk_Out.print "#{@mi_Left} #{@mi_Height - @mi_Bottom} "
					lk_Out.puts "' fill='#8ae234' fill-opacity='0.3' stroke='#73d216' stroke-width='0.75px'/>"

					# draw decoy amount
					lk_Out.print "<polyline points='"
					lk_Out.print "#{@mi_Left} #{@mi_Height - @mi_Bottom} "
					(0...lk_Histogram.size).each do |i|
						lk_Out.print "#{i.to_f / (lk_Histogram.size) * @mi_ClientWidth + @mi_Left} #{@mi_Height - @mi_Bottom - (lk_Histogram[i][:decoyCount]) * @mi_ClientHeight} "
					end
					lk_Out.print "#{@mi_Width - @mi_Right} #{@mi_Height - @mi_Bottom} "
					lk_Out.puts "' fill='#ef2929' fill-opacity='0.3' stroke='#cc0000' stroke-width='0.75px'/>"

					[1.0, 0.1, 0.01, 0.001].each do |x|
						lk_Out.puts "<polyline points='#{@mi_Left} #{@mi_Height - @mi_Bottom - (((x * 0.5) ** lf_LogScale)) * @mi_ClientHeight} #{@mi_Width - @mi_Right} #{@mi_Height - @mi_Bottom - (((x * 0.5) ** lf_LogScale)) * @mi_ClientHeight}' fill='none' stroke='#888a85' stroke-width='0.5px' />"
						lk_Out.puts "<text style='text-anchor: end; font-size: 6pt;' x='#{@mi_Left - 4}' y='#{@mi_Height - @mi_Bottom - (((x * 0.5) ** lf_LogScale)) * @mi_ClientHeight}'>#{x < 0.01 ? x * 100.0: (x * 100.0).to_i}%</text>"
					end
					
					# draw estimated FPR
					lk_Out.print "<polyline points='"
					(0...lk_Histogram.size).each do |i|
						lk_Out.print "#{i.to_f / (lk_Histogram.size) * @mi_ClientWidth + @mi_Left} #{@mi_Height - @mi_Bottom - (lk_Histogram[i][:fpr] ** lf_LogScale) * @mi_ClientHeight} " if lk_Histogram[i][:fpr] > 0.0
					end
					lk_Out.puts "' fill='none' stroke='#729fcf' stroke-width='1px'/>"

					# draw score
					ld_ScaleMinimum = Math.log10(ld_ScoreMinimum)
					lk_Out.print "<polyline points='"
					(0...lk_Histogram.size).each do |i|
						lk_Out.print "#{i.to_f / (lk_Histogram.size) * @mi_ClientWidth + @mi_Left} #{scaley(Math.log10(lk_Histogram[i][:score]), 0.0, ld_ScaleMinimum) + @mi_Top} "
					end
					lk_Out.puts "' fill='none' stroke='#8ae234' stroke-width='1px'/>"
					
					# draw lower legend
					
					li_CurrentScale = 0
					lk_ScaleSkips = [1, 2, 5]
					li_ScaleSkipIndex = 0
					li_ScaleExponent = 0
					ld_Distance = 0.0

					begin
						li_ScaleSkip = lk_ScaleSkips[li_ScaleSkipIndex] * (10 ** li_ScaleExponent)
						ld_Distance = (scale(li_CurrentScale.to_f, 0, li_TotalCount) - 
							scale(li_CurrentScale.to_f + li_ScaleSkip, 0, li_TotalCount)).abs
							
						break unless ld_Distance < 32.0
						li_ScaleSkipIndex += 1
						if (li_ScaleSkipIndex > lk_ScaleSkips.size - 1)
							li_ScaleSkipIndex = 0
							li_ScaleExponent += 1
						end
					end while ld_Distance < 32.0

					li_ScaleSkip = lk_ScaleSkips[li_ScaleSkipIndex] * (10 ** li_ScaleExponent)
					while (li_CurrentScale <= li_TotalCount)
						ld_Position = scale(li_CurrentScale.to_f, 0, li_TotalCount) + @mi_Left
						ls_Label = "#{li_CurrentScale}"
						lk_Out.puts "<polyline points='#{ld_Position} #{@mi_Height - @mi_Bottom} #{ld_Position} #{@mi_Height - @mi_Bottom + 4}' stroke='#555753' stroke-width='1.0px' />"
						lk_Out.puts "<text x='#{ld_Position}' y='#{@mi_Height - @mi_Bottom + 12}' style='font-size: 6pt; text-anchor: middle;'>#{ls_Label}</text>"
						li_CurrentScale += li_ScaleSkip
					end

					# draw right legend

					ld_ScaleMinimum = Math.log10(ld_ScoreMinimum)
					ld_ScaleStart = ld_ScaleMinimum
					ld_ScaleEnd = 1.0
					li_CurrentScale = 0
					li_ScaleSkip = 1
					ld_Distance = 0.0

					begin
						ld_Distance = (scaley(li_CurrentScale.to_f, 0.0, ld_ScaleMinimum) - 
							scaley(li_CurrentScale.to_f - li_ScaleSkip, 0.0, ld_ScaleMinimum)).abs
						break unless ld_Distance < 16.0
						li_ScaleSkip += 1
					end while ld_Distance < 16.0

					while (li_CurrentScale >= ld_ScaleMinimum)
						ld_Position = scaley(li_CurrentScale.to_f, 0.0, ld_ScaleMinimum) + @mi_Top
						ls_Label = li_CurrentScale == 0 ? '1.0' : "1e#{li_CurrentScale}"
						lk_Out.puts "<polyline points='#{@mi_Width - @mi_Right} #{ld_Position} #{@mi_Width - @mi_Right + 4} #{ld_Position}' stroke='#555753' stroke-width='1.0px' />"
						lk_Out.puts "<text x='#{@mi_Width - @mi_Right + 6.0}' y='#{ld_Position + 3.0}' style='font-size: 6pt; text-anchor: start;'>#{ls_Label}</text>"
						li_CurrentScale -= li_ScaleSkip
					end
					
					lk_Out.puts "</svg>"
				end
				lk_Out.puts '</body>'
				lk_Out.puts '</html>'
			end
		end
	end
end

lk_Object = AnalyzePsm.new
