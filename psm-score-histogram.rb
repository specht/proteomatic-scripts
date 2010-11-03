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
require './include/ruby/ext/fastercsv'
require './include/ruby/misc'
require 'bigdecimal'
require 'bigdecimal/math'
require 'bigdecimal/util'
require 'set'
require 'yaml'


include BigMath


# the following duck punch was copypasted from 
# http://codeidol.com/other/rubyckbk/Numbers/Taking-Logarithms/
module BigMath
    alias :log_slow :log
    def log(x, prec)
    if x <= 0 || prec <= 0
        raise ArgumentError, "Zero or negative argument for log"
    end 
    return x if x.infinite? || x.nan?
    sign, fraction, power, exponent = x.split 
    fraction = BigDecimal(".#{fraction}")
    power = power.to_s.to_d
    log_slow(fraction, prec) + (log_slow(power, prec) * exponent)
    end
end 


class PsmScoreHistogram < ProteomaticScript
    def run()
        psm = Array.new()

        log10 = Math::log(10)
        bins = Hash.new
        minBin = nil
        maxBin = nil
        
        peptideHash = Hash.new
        @input[:peptides].each do |path|
            print "Reading #{File::basename(path)}..."
            key = File::basename(path).split('.').first
            if peptideHash.include?(key)
                puts "Error: Please do not specify multiple peptide list files with the same filename."
                exit(1)
            end
            peptideHash[key] = File::read(path).upcase.split("\n").collect { |x| x.strip }.reject { |x| x.empty?}
            peptideHash[key].collect! { |x| x.gsub('L', 'J').gsub('I', 'J') } if @param[:useJ]
            peptideHash[key] = Set.new(peptideHash[key])
            puts " got #{peptideHash[key].size} peptides."
        end
        
        @input[:omssaResults].each do |path|
            puts "Reading #{File::basename(path)}..."
            File::open(path, 'r') do |f|
                header = mapCsvHeader(f.readline)
                f.each_line do |line|
                    lineArray = line.parse_csv()
                    peptide = lineArray[header['peptide']]
                    peptide = peptide.gsub('L', 'J').gsub('I', 'J') if @param[:useJ]
                    evalue = BigDecimal.new(lineArray[header['evalue']])
                    exponent = (BigMath::log(evalue, 3) / log10).to_f
                    bin = (exponent / @param[:stepSize]).to_i
                    bins[bin] ||= Array.new
                    bins[bin] << peptide
                    minBin ||= bin
                    minBin = bin if bin < minBin
                    maxBin ||= bin
                    maxBin = bin if bin > maxBin
                end
            end
        end
        
        # insert empty bins where there's nothing yet,
        # save us some checks below
        (minBin..maxBin).each do |bin|
            bins[bin] ||= Array.new
        end
        
        if @output[:histogram]
            File::open(@output[:histogram], 'w') do |f|
                f.print "Bin,All,Unmodified,Modified"
                peptideHash.keys.sort.each do |key|
                    f.print ",\"#{key} unmodified\",\"#{key} modified\""
                end
                f.puts
                (minBin..maxBin).each do |bin|
                    printBin = sprintf('%1.3f', bin * @param[:stepSize])
                    allCount = bins[bin].size
                    unmodifiedCount = bins[bin].select do |x|
                        !(x =~ /[a-z]/)
                    end.size
                    modifiedCount = bins[bin].select do |x|
                        (x =~ /[a-z]/)
                    end.size
                    f.print "#{printBin},#{allCount},#{unmodifiedCount},#{modifiedCount}"
                    peptideHash.keys.sort.each do |key|
                        unmodifiedCount = bins[bin].select do |x|
                            !(x =~ /[a-z]/) && (peptideHash[key].include?(x.upcase))
                        end.size
                        modifiedCount = bins[bin].select do |x|
                            (x =~ /[a-z]/) && (peptideHash[key].include?(x.upcase))
                        end.size
                        f.print ",#{unmodifiedCount},#{modifiedCount}"
                    end
                    f.puts
                end
            end
        end
    end
end

lk_Object = PsmScoreHistogram.new
