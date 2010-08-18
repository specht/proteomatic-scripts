require 'include/ruby/proteomatic'
require 'fileutils'

class QTraceCropXhtmlReport < ProteomaticScript
    def run()
        requirements = Hash.new
        unless @param[:peptides].empty?
            items = @param[:peptides].split(/\s/).reject { |x| x.empty? }
            requirements['PEPTIDE'] = items unless items.empty?
        end
        unless @param[:charges].empty?
            items = @param[:charges].split(/\s/).reject { |x| x.empty? }
            requirements['CHARGE'] = items unless items.empty?
        end
        unless @param[:spectraFiles].empty?
            items = @param[:spectraFiles].split(/\s/).reject { |x| x.empty? }
            requirements['BAND'] = items unless items.empty?
        end
        unless @param[:scanIds].empty?
            items = @param[:scanIds].split(/\s/).reject { |x| x.empty? }
            requirements['SCAN'] = items unless items.empty?
        end
        allQeCount = 0
        copiedQeCount = 0
        
        quantitationEventKeys = Set.new
        useQeFilter = false
        
        @input[:quantitationEvents].each do |path|
            useQeFilter = true
            File::open(path, 'r') do |f|
                header = mapCsvHeader(f.readline)
                f.each_line do |line|
                    lineArray = line.parse_csv()
                    peptide = lineArray[header['peptide']]
                    charge = lineArray[header['charge']].to_i
                    band = lineArray[header['filename']]
                    scanId = lineArray[header['scanid']]
                    quantitationEventKeys << "PEPTIDE #{peptide} CHARGE #{charge} BAND #{band} SCAN #{scanId}"
                end
            end
        end
        
        @output.each do |inPath, outPath|
            File::open(outPath, 'w') do |fo|
                File::open(inPath, 'r') do |fi|
                    copyLine = true
                    fi.each_line do |line|
                        if line.strip[0, 10] == '<!-- BEGIN'
                            allQeCount += 1
                            copyLine = true
                            requirements.each_pair do |cat, values|
                                anyMatch = false
                                values.each do |value|
                                    s = cat + ' ' + value
                                    if line.include?(s)
                                        anyMatch = true
                                        break
                                    end
                                end
                                unless anyMatch
                                    copyLine = false 
                                    break
                                end
                            end
                            if useQeFilter
                                key = line.dup
                                key.sub!('<!-- BEGIN', '')
                                key.sub!('-->', '')
                                key.strip!
                                copyLine = false unless quantitationEventKeys.include?(key)
                            end
                            copiedQeCount +=1 if copyLine
                        end
                        fo.puts line if copyLine
                        copyLine = true if line.strip[0, 8] == '<!-- END'
                    end
                end
            end
        end
        puts "Cropped #{copiedQeCount} from a total of #{allQeCount} quantitation events."
    end
end

lk_Object = QTraceCropXhtmlReport.new
