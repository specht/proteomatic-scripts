require 'include/proteomatic'
require 'fileutils'

class StripMs1Scans < ProteomaticScript
	def run()
		@output.each do |ls_InPath, ls_OutPath|
			ls_TempOutPath = tempFilename('strip-ms1-scans', File.dirname(ls_OutPath))
			FileUtils::mkpath(ls_TempOutPath)
			print "#{File.basename(ls_InPath)}: "
			
			ls_OldDir = Dir.pwd
			Dir.chdir(ls_TempOutPath)
			# call stripscans
			ls_Command = "#{ExternalTools::binaryPath('ptb.stripscans')} \"#{ls_InPath}\""
			print 'stripping'
			$stdout.flush
			runCommand(ls_Command)
			Dir.chdir(ls_OldDir)
			
			unless (@param[:compression].empty?)
				ls_OldDir = Dir::pwd()
				
				ls_7ZipPath = ExternalTools::binaryPath('7zip.7zip')
				Dir.chdir(ls_TempOutPath)
				
				print ', compressing'
				$stdout.flush
				
				# zip mzXML file
				lk_Files = Dir['*']
				ls_Command = "#{ls_7ZipPath} a -t#{@param[:compression] == '.gz' ? 'gzip' : 'bzip2'} #{lk_Files.first + @param[:compression]} #{lk_Files.first} -mx5"
				runCommand(ls_Command)
				FileUtils::rm_f(lk_Files.first)
				
				Dir.chdir(ls_OldDir)
			end
			
			lk_Files = Dir[File.join(ls_TempOutPath, '*')]
			FileUtils::mv(lk_Files.first, ls_OutPath)
			FileUtils::mv(ls_OutPath, ls_OutPath.sub('.proteomatic.part', ''))
			puts ' - done.'
			$stdout.flush
			FileUtils::rm_rf(ls_TempOutPath)
		end
	end
end

lk_Object = StripMs1Scans.new
