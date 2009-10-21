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
require 'include/externaltools'
require 'include/fasta'
require 'include/ext/fastercsv'
require 'include/formats'
require 'include/misc'
require 'set'
require 'yaml'
require 'fileutils'

class RunBlast < ProteomaticScript
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
        resultFile = tempFilename('run-blast-results')
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
                        outFile.puts ">query_#{i}"
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
        command = "\"#{ExternalTools::binaryPath('blast.blastall')}\" "
        command += @mk_Parameters.commandLineFor("blast.blastall") + " "
        # database file
        command += "-d \"#{databases.to_a.first}\" "
        # input query file
        command += "-i \"#{queryFile}\" "
        # XML output
        command += "-m 7 "
        # redirect output
        command += "-o \"#{resultFile}\""
        print('Running BLAST...')
        runCommand(command, true)
        puts('done.')
        
        FileUtils::mv(resultFile, @output[:resultFile]) if @output[:resultFile]
    end
end

lk_Object = RunBlast.new
