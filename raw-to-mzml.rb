#! /usr/bin/env ruby
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

require './include/ruby/proteomatic'
require 'fileutils'

class Raw2MzML < ProteomaticScript
    def run()
        # use the local temporary directory for this script (big files, man!)
        ls_TempOutPath = tempFilename('raw-to-mzml', Dir::tmpdir)
        FileUtils.mkpath(ls_TempOutPath)
        @output.each do |ls_InPath, ls_OutPath|
            # clean up temp dir
            FileUtils::rm_rf(File::join(ls_TempOutPath, '*'))
            
            print "#{File.basename(ls_InPath)}: "
            
            # call msconvert
            ls_Command = "\"#{ExternalTools::binaryPath('pwiz.msconvert')}\" #{@mk_Parameters.commandLineFor('pwiz.msconvert')} \"#{ls_InPath}\" -o \"#{ls_TempOutPath}\""

            print 'converting'
            $stdout.flush

            runCommand(ls_Command)
            
            # strip MS1 scans if desired
            # Note: msconvert has the --stripIT option to strip MS1 ion trap scans, but 
            # it didn't strip our MS1 scans when I tried it, so we use ptb.stripscans here
            
            unless (@param[:stripMs1Scans].empty?)
                ls_OldDir = Dir::pwd()
                
                ls_StripScansPath = ExternalTools::binaryPath('ptb.stripscans')
                Dir.chdir(ls_TempOutPath)
                
                print ', stripping'
                $stdout.flush
                
                # strip mzML file
                lk_Files = Dir['*']
                ls_Command = "\"#{ls_StripScansPath}\" \"#{lk_Files.first}\""
                runCommand(ls_Command)
                FileUtils::rm_f(lk_Files.first)
                
                Dir.chdir(ls_OldDir)
            end
            
            unless (@param[:compression].empty?)
                ls_OldDir = Dir::pwd()
                
                ls_7ZipPath = ExternalTools::binaryPath('7zip.7zip')
                Dir.chdir(ls_TempOutPath)
                
                print ', compressing'
                $stdout.flush
                
                # zip mzML file
                lk_Files = Dir['*']
                ls_Command = "\"#{ls_7ZipPath}\" a -t#{@param[:compression] == '.gz' ? 'gzip' : 'bzip2'} \"#{lk_Files.first + @param[:compression]}\" \"#{lk_Files.first}\" -mx5"
                runCommand(ls_Command)
                FileUtils::rm_f(lk_Files.first)
                
                Dir.chdir(ls_OldDir)
            end
            
            lk_Files = Dir[File.join(ls_TempOutPath, '*')]
            FileUtils::mv(lk_Files.first, ls_OutPath)
            FileUtils::mv(ls_OutPath, ls_OutPath.sub('.proteomatic.part', ''))
            puts ' - done.'
            $stdout.flush
        end
        FileUtils::rm_rf(ls_TempOutPath)
    end
end

script = Raw2MzML.new
