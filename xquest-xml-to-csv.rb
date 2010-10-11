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
require 'rexml/document'
require 'rexml/streamlistener'

include REXML

class XmlParser
    include REXML::StreamListener
    
    def initialize(outStream)
        @outStream = outStream
        @info = {:lines => []}
        @outStream.puts "Filename,Precursor m/z,Charge,Rank,Id,Structure,Type,XCorr X,XCorr BB,PRMI,Score,Error (ppm),Topology"
    end
    
    def tag_start(element, attributes)
        if element == 'tr'
            @line = []
        end
        if element == 'td' || element == 'th'
            @line << ''
        end
    end

    def tag_end(element)
        if element == 'tr'
            handleLine()
        end
    end
    
    def text(text)
        if @line && @line.size > 0
            @line.last << text
        end
    end
    
    def handleLine()
#         we have three types of lines:
#         handling line: [, 826.108215, 3, id: C__Xcalibur_sequest_xquest_EO_DSS042010_HCD+FT_11052010_04.105.105.3_C__Xcalibur_sequest_xquest_EO_DSS042010_HCD+FT_11052010_04.105.105.3]
#         handling line: [rank, id, structure, type, xcorrx, xcorrbb, PRMI, score, error [ppm], topology, spectrum]
#         handling line: [1, GAKK-KPGSQGEPGSFLGFEASLK-a3-b1, GAKK-KPGSQGEPGSFLGFEASLK, xlink, 0.05464, -0.00651, , 12.35, 0.1, a3-b1, spectrum]
        if @line[0].empty?
            # it's a scan line with precursor m/z, charge, and scan id!
            finishBlock()
            @info[:precursorMz] = @line[1]
            @info[:precursorCharge] = @line[2]
            @info[:scanId] = @line[3]
        else
            unless @line[0].downcase == 'rank'
                @info[:lines] << @line
            end
        end
    end
    
    def finishBlock()
        return if @info[:lines].empty?
        @info[:lines].each do |l|
            while l.size > 10
                l.pop
            end
            @outStream.puts "\"#{@info[:scanId]}\",\"#{@info[:precursorMz]}\",\"#{@info[:precursorCharge]}\",#{l.collect { |x| '"' + x + '"' }.join(',')}"
        end
        # now clear info block
        @info = {:lines => []}
    end
end

class XQuestXmlToCsv < ProteomaticScript
    def run()
        @input[:xmlFiles].each do |path|
            File::open(path, 'r') do |f|
                File::open(@output[path], 'w') do |fout|
                    parser = XmlParser.new(fout)
                    REXML::Document.parse_stream(f, parser)
                    parser.finishBlock()
                end
            end
        end
    end
end

lk_Object = XQuestXmlToCsv.new
