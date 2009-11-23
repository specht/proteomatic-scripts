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
require 'include/ruby/externaltools'
require 'include/ruby/fasta'
require 'include/ruby/ext/fastercsv'
require 'include/ruby/formats'
require 'include/ruby/misc'
require 'set'
require 'yaml'
require 'fileutils'

class RunBlast < ProteomaticScript
    def runBlast(databasePath, queryBatchPath, resultPath)
        tempResultPath = tempFilename('run-blast-results')
        command = "\"#{ExternalTools::binaryPath('blast.blastall')}\" "
        command += @mk_Parameters.commandLineFor("blast.blastall") + " "
        # database file
        command += "-d \"#{databasePath}\" "
        # input query file
        command += "-i \"#{queryBatchPath}\" "
        # XML output
        command += "-m 7 "
        # redirect output
        command += "-o \"#{tempResultPath}\""
        runCommand(command, true)
        
        cache = Hash.new
        File::open(resultPath, 'a') do |out|
            File::open(tempResultPath, 'r') do |f|
                f.each_line do |line|
                    line.strip!
                    content = line.gsub(/\<[^\>]+\>/, '')
                    
                    cache[:iteration] = Hash.new if line.index('<Iteration>') == 0
                    cache[:hit] = Hash.new if line.index('<Hit>') == 0
                    cache[:hsp] = Hash.new if line.index('<Hsp>') == 0
                    
                    cache[:iteration][:queryDef] = content if line.index('<Iteration_query-def>') == 0
                    
                    cache[:hit][:hitId]= content if line.index('<Hit_id>') == 0
                    cache[:hit][:hitDef]= content if line.index('<Hit_def>') == 0

                    cache[:hsp][:hspBitScore]= content if line.index('<Hsp_bit-score>') == 0
                    cache[:hsp][:hspScore]= content if line.index('<Hsp_score>') == 0
                    cache[:hsp][:hspEValue]= content if line.index('<Hsp_evalue>') == 0
                    cache[:hsp][:qSeq]= content if line.index('<Hsp_qseq>') == 0
                    cache[:hsp][:hSeq]= content if line.index('<Hsp_hseq>') == 0
                    cache[:hsp][:midLine]= content if line.index('<Hsp_midline>') == 0
                    
                    if line.index('</Hsp>') == 0
                        # reached the end of a HSP, print it
                        #puts cache.to_yaml
                        list = Array.new
                        list << cache[:iteration][:queryDef]
                        list << cache[:hit][:hitId]
                        list << cache[:hit][:hitDef]
                        list << cache[:hsp][:hspBitScore]
                        list << cache[:hsp][:hspScore]
                        list << cache[:hsp][:hspEValue]
                        list << cache[:hsp][:qSeq]
                        list << cache[:hsp][:hSeq]
                        list << cache[:hsp][:midLine]
                        out.puts list.to_csv()
                    end
                end
            end
        end
        FileUtils::rm(tempResultPath)
    end
    
    def run()
        databases = Set.new
        @input[:databases].each do |path|
            if fileMatchesFormat(path, 'blastdb')
                # strip .00.pin / .psq / .phr
                strippedPath = path[0, path.size - 4]
                if strippedPath.rindex(/\.\d\d/) == strippedPath.size - 3
                    # strip .00 trailing number
                    strippedPath = strippedPath[0, strippedPath.size - 3]
                end
                databases << strippedPath
            else
                # convert FASTA database to BLAST
            end
        end
        if databases.size != 1
            puts "Error: You cannot specify more than one database for BLAST."
            exit 1
        end
        unless @output[:csvResults]
            puts "Notice: CSV output not activated. Skipping BLAST..."
            exit 0
        end
        resultFile = @output[:csvResults]
        File::open(resultFile, 'w') do |f|
            list = ['Query Def', 'Hit Id', 'Hit Def', 'Hsp Bit Score', 'Hsp Score', 'HSP E-value', 'Query Sequence', 'Hit Sequence', 'Mid line']
            f.puts list.to_csv()
        end
        
        queryFile = nil
        unless @param[:peptides].empty?
            peptides = @param[:peptides].split(%r{[,;\s/]+})
            peptides.reject! { |x| x.strip.empty? }
            peptides.collect! { |x| x.strip }
            peptides.uniq!
            unless peptides.empty?
                queryFile ||= tempFilename('run-blast')
                File::open(queryFile, 'a') do |outFile|
                    i = 0
                    peptides.each do |peptide|
                        i += 1
                        outFile.puts ">query_#{i} #{peptide}"
                        outFile.puts peptide
                    end
                end
            end
        end
            
        if queryFile || (@input[:queries].size > 1)
            queryFile ||= tempFilename('run-blast')
            File::open(queryFile, 'a') do |out|
                @input[:queries].each do |path|
                    out.puts(File::read(path))
                end
            end
        else
            queryFile = @input[:queries].first
        end
        
        # now extract small batches from queryFile
        # with the nr database, one query produced ~600 KiB of XML,
        # so do batches of 20, we'll have about 12 MiB of XML
        
        queryBatchPath = tempFilename('run-blast-query-batch')
        
        File::open(queryFile, 'r') do |queryIn|
            batchSize = 0
            queryCount = 0
            queryOut = File::open(queryBatchPath, 'w')
            queryIn.each_line do |line|
                if (line.strip[0, 1] == '>')
                    # a new query starts here
                    if batchSize >= 20
                        # we have 20 queries now, run BLAST
                        queryOut.close
                        runBlast(databases.to_a.first, queryBatchPath, resultFile)
                        print("\rRunning BLAST, processed #{queryCount} queries...")
                        # clear query batch file
                        queryOut = File::open(queryBatchPath, 'w')
                        batchSize = 0
                    end
                    batchSize += 1
                    queryCount += 1
                end
                queryOut.puts(line)
            end
            queryOut.close
            # run BLAST if we have queries left
            if batchSize > 0
                runBlast(databases.to_a.first, queryBatchPath, resultFile)
                print("\rRunning BLAST, processed #{queryCount} queries...")
            end
            puts
        end
    end
end

lk_Object = RunBlast.new
