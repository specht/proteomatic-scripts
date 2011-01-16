#! /usr/bin/env ruby
require './include/ruby/proteomatic'
require './include/ruby/evaluate-omssa-helper'
require 'fileutils'
require 'set'


class StripMs1Scans < ProteomaticScript
    def run()
        # scanIds: # in certain mzml files
        #   MT_CP_blabla_01: Set([113, 100])
        # allScanIds: Set([113, 100]) # in all mzml files
        scanIds = Hash.new
        allScanIds = Set.new

        @input[:scanIds].each do |path|
            File::open(path) do |f|
                f.each_line do |line|
                    line.strip!
                    next if line.empty?
                    id = line.to_i
                    allScanIds << id
                end
            end
        end

        @input[:psmList].each do |path|
            results = loadPsm(path)
            results[:scanHash].each_key do |scanKey|
                scanKeyList = scanKey.split('.')
                filename = scanKeyList[0, scanKeyList.size - 3].join('.')
                scanId = scanKeyList[-3]
                filename.chomp!('-no-ms1')
                filename.chomp!('-stripped')

                scanIds[filename] ||= Set.new
                scanIds[filename] << scanId
            end
        end

        @output.each do |ls_InPath, ls_OutPath|
            filename = File::basename(ls_InPath).split('.').first
            filename.chomp!('-no-ms1')
            filename.chomp!('-stripped')

            thisScanIds = scanIds[filename]
            thisScanIds ||= Set.new
            thisScanIds |= allScanIds

            ls_TempOutPath = tempFilename('strip-mzml', File.dirname(ls_OutPath))
            FileUtils::mkpath(ls_TempOutPath)
            ls_ScanIdsPath = File::join(ls_TempOutPath, 'scan-ids.txt')
            ls_StrippedMzMlPath = File::join(ls_TempOutPath, 'stripped.mzml')

            unless ls_ScanIdsPath.empty?
                File::open(ls_ScanIdsPath, 'w') do |f|
                    f.puts thisScanIds.to_a.join("\n")
                end
            end

            puts "Stripping #{File.basename(ls_InPath)}..."
            $stdout.flush

            # call stripscans
            scanIdOption = "--#{@param[:scanIdAction]}ScanIds \"#{ls_ScanIdsPath}\""
            scanIdOption = '' if thisScanIds.empty?
            ls_Command = "#{ExternalTools::binaryPath('ptb.stripscans')} --quiet --outputPath \"#{ls_StrippedMzMlPath}\" --stripMsLevels \"#{@param[:stripMsLevels]}\" #{scanIdOption} \"#{ls_InPath}\""
            runCommand(ls_Command)

            unless (@param[:compression].empty?)
                ls_7ZipPath = ExternalTools::binaryPath('7zip.7zip')
                ls_Command = "\"#{ls_7ZipPath}\" a -t#{@param[:compression] == '.gz' ? 'gzip' : 'bzip2'} \"#{ls_OutPath}\" \"#{ls_StrippedMzMlPath}\" -mx5"
                runCommand(ls_Command)
            else
                FileUtils::mv(ls_StrippedMzMlPath, ls_OutPath)
            end

            FileUtils::mv(ls_OutPath, ls_OutPath.sub('.proteomatic.part', ''))
            FileUtils::rm_rf(ls_TempOutPath)
        end
    end
end

lk_Object = StripMs1Scans.new
