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

require 'include/ruby/proteomatic'
require 'include/ruby/ext/fastercsv'
require 'include/ruby/misc'
require 'yaml'

$gk_Gradient = {'burn' => [
    [0.0, '#ffffff'],
    [0.2, '#fce94f'],
    [0.4, '#fcaf3e'],
    [0.7, '#a40000'],
    [1.0, '#000000']
    ],
    'grayscale' => [
    [0.0, '#ffffff'],
    [1.0, '#000000']
    ],
    'extremes' => [
    [0.0, '#ffffff'],
    [0.001, '#fce94f'],
    [0.5, '#f57900'],
    [0.999, '#a40000'],
    [1.0, '#000000']
    ]}
    
    
def mix(a, b, amount)
    rA = Integer('0x' + a[1, 2]).to_f / 255.0
    gA = Integer('0x' + a[3, 2]).to_f / 255.0
    bA = Integer('0x' + a[5, 2]).to_f / 255.0
    rB = Integer('0x' + b[1, 2]).to_f / 255.0
    gB = Integer('0x' + b[3, 2]).to_f / 255.0
    bB = Integer('0x' + b[5, 2]).to_f / 255.0
    rC = rB * amount + rA * (1.0 - amount)
    gC = gB * amount + gA * (1.0 - amount)
    bC = bB * amount + bA * (1.0 - amount)
    result = sprintf('#%02x%02x%02x', (rC * 255.0).to_i, (gC * 255.0).to_i, (bC * 255.0).to_i)
    return result
end
    
    
def gradient(x)
    x = 0.0 if x < 0.0
    x = 1.0 if x > 1.0
    i = 0
    while (i < $gk_Gradient[@param[:gradient]].size - 2 && $gk_Gradient[@param[:gradient]][i + 1][0] < x)
        i += 1
    end
    colorA = $gk_Gradient[@param[:gradient]][i][1]
    colorB = $gk_Gradient[@param[:gradient]][i + 1][1]
    return mix(colorA, colorB, (x - $gk_Gradient[@param[:gradient]][i][0]) / ($gk_Gradient[@param[:gradient]][i + 1][0] - $gk_Gradient[@param[:gradient]][i][0]))
end
    

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
                drKey = 'd'
                drKey = 'r' unless header[drKey]
                f.each_line do |line|
                    lineArray = line.parse_csv()
                    ls_Product = "#{lineArray[header['a']]}/#{lineArray[header[drKey]]}"
                    lk_Amounts[ls_Product] ||= 0.0
                    lk_Amounts[ls_Product] += lineArray[header['amount']].to_f
                end
            end
            
            # scale all so that maximum is at 1.0
            lk_Sum = Hash.new
            lk_Max = Hash.new
            lk_Amounts.keys.each do |key| 
                dp = key.split('/')[0].to_i + key.split('/')[1].to_i
                dp = 0 unless @param[:normalizeWithinRings] == 'yes'
                x = lk_Amounts[key]
                lk_Sum[dp] ||= 0.0
                lk_Max[dp] ||= 0.0
                lk_Sum[dp] += x
                lk_Max[dp] = x if x > lk_Max[dp]
            end
            if @param[:normalize] == 'sum'
                lk_Amounts.keys.each do |key| 
                    dp = key.split('/')[0].to_i + key.split('/')[1].to_i
                    dp = 0 unless @param[:normalizeWithinRings] == 'yes'
                    lk_Amounts[key] /= lk_Sum[dp]
                end
            elsif @param[:normalize] == 'maximum'
                lk_Amounts.keys.each do |key| 
                    dp = key.split('/')[0].to_i + key.split('/')[1].to_i
                    dp = 0 unless @param[:normalizeWithinRings] == 'yes'
                    lk_Amounts[key] /= lk_Max[dp]
                end
            end
            
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
                end.each do |product|
                    amount = lk_Amounts[product]
                    # ld_DP0 = pow(ld_DP0, 0.1) * 2.0 - 1.0;
                    amountA = product.split('/')[0].to_i
                    amountD = product.split('/')[1].to_i
                    dp = amountA + amountD
                    da = amountA.to_f / dp
                    r0 = 500.0 * (1.0 - (dp ** (-@param[:radiusExponent])))
                    r1 = 500.0 * (1.0 - ((dp + 1) ** (-@param[:radiusExponent])))
                    a0 = 1.0 / (dp + 1) * amountA
                    a1 = 1.0 / (dp + 1) * (amountA + 1)
                    amount = (1.0 - amount) ** @param[:valueExponent]
                    color = gradient(1.0 - amount)
                    angle = 2.0 * Math.asin(0.5 / (2.0 * r1)) / Math::PI
                    a0 -= angle unless amountA == 0
                    a1 += angle unless amountA == dp
                    arcs += arc(r0 - 0.3, r1 + 0.3, a0, a1, "#{color}")
                end
                maxDP = @param[:gridMaxDP]
                (1..maxDP).each do |dp|
                    r = 500.0 * (1.0 - ((dp + 1) ** (-@param[:radiusExponent])))
                    arcs += "<path d='M#{-r},0 A#{r},#{r},0,0,0,#{r},0' fill='none' stroke='#ffffff' style='stroke-width: 4px; stroke-opacity: #{0.5 - 0.5 * dp.to_f / maxDP};' />\n" if @param[:gridColor] == '#000000'
                    arcs += "<path d='M#{-r},0 A#{r},#{r},0,0,0,#{r},0' fill='none' stroke='#{@param[:gridColor]}' style='stroke-width: 1.2px; stroke-opacity: #{1.0 - (dp.to_f / maxDP) ** 2.0};' />\n"
                    (0..(dp + 1)).each do |da|
                        angle = da.to_f * Math::PI / (dp + 1)
                        r0 = 500.0 * (1.0 - (dp ** (-@param[:radiusExponent])))
                        r1 = 500.0 * (1.0 - ((dp + 1) ** (-@param[:radiusExponent])))
                        arcs += "<line x1='#{Math.cos(angle) * r0}' y1='#{Math.sin(angle) * r0}' x2='#{Math.cos(angle) * r1}' y2='#{Math.sin(angle) * r1}' fill='none' stroke='#ffffff' style='stroke-width: 4px; stroke-opacity: #{0.5 - 0.5 * (dp.to_f / maxDP) ** 2.0};' />\n"  if @param[:gridColor] == '#000000'
                        arcs += "<line x1='#{Math.cos(angle) * r0}' y1='#{Math.sin(angle) * r0}' x2='#{Math.cos(angle) * r1}' y2='#{Math.sin(angle) * r1}' fill='none' stroke='#{@param[:gridColor]}' style='stroke-width: 1.2px; stroke-opacity: #{1.0 - (dp.to_f / maxDP) ** 2.0};' />\n"
                    end
                end
                ls_Svg = ls_SvgTemplate.dup
                ls_Svg.sub!('#{PRODUCTS}', arcs);
                ls_Gradient = ''
                $gk_Gradient[@param[:gradient]].each do |pair|
                    ls_Gradient += "<stop offset='#{pair[0] * 100.0}%' style='stop-color:#{pair[1]}; stop-opacity:1'/>\n"
                end
                ls_Svg.sub!('#{GRADIENT}', ls_Gradient);
                ls_Legend = ''
                [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0].each do |a|
                    ls_Legend += "<text text-anchor='end' x='990' y='#{348 + a * 200.0}' fill='#000' style='font-family: Bitstream Charter' font-size='16px'>#{sprintf('%1.2g', 1.0 - (a ** (1.0 / @param[:valueExponent])))}</text>"
                end
                ls_Svg.sub!('#{LEGEND}', ls_Legend);

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
<defs>
<linearGradient id="burn" x1="0%" y1="100%" x2="0%" y2="0%">
#{GRADIENT}
</linearGradient>
</defs>
#{PRODUCTS}
</g>
<line x1='500' y1='0' x2='30' y2='0' fill='none' stroke='#000' stroke-width='2.5' marker-end='url(#arrow)' />
<path transform='translate(500, 0) scale(1, -1) translate(-500, 0)' d='M 0,0 a 500,500 -180 0,1 1000,0' fill='none' stroke='#000' stroke-width='2.5' marker-end='url(#arrow)' />
<text x='10' y='-10' fill='#000' style='font-family: Bitstream Charter' font-size='20px'>DP</text>
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
<rect x='1000' y='340' width='20' height='200' style='fill:url(#burn)'/>
#{LEGEND}
</g>
</svg>
