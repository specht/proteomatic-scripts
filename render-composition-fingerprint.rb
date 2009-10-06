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
require 'include/ext/fastercsv'
require 'include/misc'
require 'yaml'


class RenderCompositionFingerprint < ProteomaticScript
	def arc(r0, r1, a0, a1, color)
		p0 = Math::PI * a0
		p1 = Math::PI * a1
		x0 = Math.cos(p0 + Math::PI) * r0
		y0 = -Math.sin(p0 + Math::PI) * r0
		x1 = Math.cos(p0 + Math::PI) * r1
		y1 = -Math.sin(p0 + Math::PI) * r1
		x2 = Math.cos(p1 + Math::PI) * r1
		y2 = -Math.sin(p1 + Math::PI) * r1
		x3 = Math.cos(p1 + Math::PI) * r0
		y3 = -Math.sin(p1 + Math::PI) * r0
		return "<path d='M#{x0},#{y0} L#{x1},#{y1} A#{r1},#{r1},0,0,0,#{x2},#{y2} L#{x3},#{y3} A#{r0},#{r0},0,0,1,#{x0},#{y0}' fill='#{color}' />"
	end

	def run()
		ls_SvgTemplate = DATA.read

		@input[:csvFiles].each do |ls_InPath|
			
			# parse composition fingerprint
			lk_Amounts = Hash.new
			File::open(ls_InPath, 'r') do |f|
				header = mapCsvHeader(f.readline)
				f.each_line do |line|
					lineArray = line.parse_csv()
					ls_Product = "#{lineArray[header['a']]}/#{lineArray[header['d']]}"
					lk_Amounts[ls_Product] ||= 0.0
					lk_Amounts[ls_Product] += lineArray[header['amount']].to_f
				end
			end
			
			# scale all so that maximum is at 1.0
			ld_Maximum = 0.0
			lk_Amounts.values.each { |x| ld_Maximum = x if x > ld_Maximum }
			lk_Amounts.keys.each { |x| lk_Amounts[x] /= ld_Maximum }
			
			# render SVG
			File::open(@output[ls_InPath], 'w') do |f|
				arcs = ''
				lk_Amounts.keys.sort do |a, b|
					aa = a.split('/')[0].to_i
					ad = a.split('/')[1].to_i
					adp = aa + ad
					ba = b.split('/')[0].to_i
					bd = b.split('/')[1].to_i
					bdp = ba + bd
					(adp == bdp) ? (aa <=> ba) : (adp <=> bdp)
				end. each do |product|
					amount = lk_Amounts[product]
					# ld_DP0 = pow(ld_DP0, 0.1) * 2.0 - 1.0;
					amountA = product.split('/')[0].to_i
					amountD = product.split('/')[1].to_i
					dp = amountA + amountD
					da = amountA.to_f / dp
					r0 = 500.0 * (1.0 - (dp ** -0.2))
					r1 = 500.0 * (1.0 - ((dp + 1) ** -0.2))
					a0 = 1.0 / (dp + 1) * amountA
					a1 = 1.0 / (dp + 1) * (amountA + 1)
					color = sprintf('%02x', ((1.0 - amount) ** 10.0)* 255.0)
					angle = 2.0 * Math.asin(0.5 / (2.0 * r1)) / Math::PI
					a0 -= angle unless amountA == 0
					a1 += angle unless amountA == dp
					arcs += arc(r0 - 0.3, r1 + 0.3, a0, a1, "##{color}#{color}#{color}")
				end
				ls_Svg = ls_SvgTemplate.dup
				ls_Svg.sub!('#{PRODUCTS}', arcs);
				f.puts ls_Svg
			end
		end
	end
end

lk_Object = RenderCompositionFingerprint.new

__END__
<?xml version='1.0' encoding='UTF-8' standalone='no'?> <svg xmlns:svg='http://www.w3.org/2000/svg' xmlns='http://www.w3.org/2000/svg' version='1.0' width='1080' height='600'> <rect x='0' y='0' width='1080' height='600' fill='white' />
<marker id='arrow' viewBox='0 0 20 10' refX='0' refY='5' markerUnits='strokeWidth' markerWidth='8' markerHeight='6' orient='auto' fill='#000'><path d='M 0 0 L 20 5 L 0 10 z' /></marker>
<g transform='translate(40,40)'>
<g transform='translate(500,0)'>
#{PRODUCTS}
</g>
<line x1='500' y1='0' x2='500' y2='470' fill='none' stroke='#000' stroke-width='2.5' marker-end='url(#arrow)' />
<path transform='translate(500, 0) scale(1, -1) translate(-500, 0)' d='M 0,0 a 500,500 -180 0,1 1000,0' fill='none' stroke='#000' stroke-width='2.5' marker-end='url(#arrow)' />
<text x='510' y='476' fill='#000' style='font-family: Bitstream Charter' font-size='20px'>DP</text>
<text x='965' y='10' fill='#000' style='font-family: Bitstream Charter' font-size='20px'>DA</text>
<text fill='#000' transform='translate(500, 0) rotate(90) translate(-500, 0)' text-anchor='middle' x='500' y='522' style='font-family: Bitstream Charter' font-size='20px'>0%</text>
<line fill='none' stroke='#000' stroke-width='2.5' transform='translate(500, 0) rotate(90) translate(-500, 0)' x1='500' y1='495' x2='500' y2='505' />
<text fill='#000' transform='translate(500, 0) rotate(72) translate(-500, 0)' text-anchor='middle' x='500' y='522' style='font-family: Bitstream Charter' font-size='20px'>10%</text>
<line fill='none' stroke='#000' stroke-width='2.5' transform='translate(500, 0) rotate(72) translate(-500, 0)' x1='500' y1='495' x2='500' y2='505' />
<text fill='#000' transform='translate(500, 0) rotate(54) translate(-500, 0)' text-anchor='middle' x='500' y='522' style='font-family: Bitstream Charter' font-size='20px'>20%</text>
<line fill='none' stroke='#000' stroke-width='2.5' transform='translate(500, 0) rotate(54) translate(-500, 0)' x1='500' y1='495' x2='500' y2='505' />
<text fill='#000' transform='translate(500, 0) rotate(36) translate(-500, 0)' text-anchor='middle' x='500' y='522' style='font-family: Bitstream Charter' font-size='20px'>30%</text>
<line fill='none' stroke='#000' stroke-width='2.5' transform='translate(500, 0) rotate(36) translate(-500, 0)' x1='500' y1='495' x2='500' y2='505' />
<text fill='#000' transform='translate(500, 0) rotate(18) translate(-500, 0)' text-anchor='middle' x='500' y='522' style='font-family: Bitstream Charter' font-size='20px'>40%</text>
<line fill='none' stroke='#000' stroke-width='2.5' transform='translate(500, 0) rotate(18) translate(-500, 0)' x1='500' y1='495' x2='500' y2='505' />
<text fill='#000' transform='translate(500, 0) rotate(0) translate(-500, 0)' text-anchor='middle' x='500' y='522' style='font-family: Bitstream Charter' font-size='20px'>50%</text>
<line fill='none' stroke='#000' stroke-width='2.5' transform='translate(500, 0) rotate(0) translate(-500, 0)' x1='500' y1='495' x2='500' y2='505' />
<text fill='#000' transform='translate(500, 0) rotate(-18) translate(-500, 0)' text-anchor='middle' x='500' y='522' style='font-family: Bitstream Charter' font-size='20px'>60%</text>
<line fill='none' stroke='#000' stroke-width='2.5' transform='translate(500, 0) rotate(-18) translate(-500, 0)' x1='500' y1='495' x2='500' y2='505' />
<text fill='#000' transform='translate(500, 0) rotate(-36) translate(-500, 0)' text-anchor='middle' x='500' y='522' style='font-family: Bitstream Charter' font-size='20px'>70%</text>
<line fill='none' stroke='#000' stroke-width='2.5' transform='translate(500, 0) rotate(-36) translate(-500, 0)' x1='500' y1='495' x2='500' y2='505' />
<text fill='#000' transform='translate(500, 0) rotate(-54) translate(-500, 0)' text-anchor='middle' x='500' y='522' style='font-family: Bitstream Charter' font-size='20px'>80%</text>
<line fill='none' stroke='#000' stroke-width='2.5' transform='translate(500, 0) rotate(-54) translate(-500, 0)' x1='500' y1='495' x2='500' y2='505' />
<text fill='#000' transform='translate(500, 0) rotate(-72) translate(-500, 0)' text-anchor='middle' x='500' y='522' style='font-family: Bitstream Charter' font-size='20px'>90%</text>
<line fill='none' stroke='#000' stroke-width='2.5' transform='translate(500, 0) rotate(-72) translate(-500, 0)' x1='500' y1='495' x2='500' y2='505' />
<text fill='#000' transform='translate(500, 0) rotate(-90) translate(-500, 0)' text-anchor='middle' x='500' y='522' style='font-family: Bitstream Charter' font-size='20px'>100%</text>
<!--
<text x='0' y='548' fill='#000' style='font-family: Bitstream Charter' font-size='20px'>enzyme: A|D, DP: 1000, DA: 11, 1000 iterations, error: 0.000238406</text>
-->
</g>
</svg>
