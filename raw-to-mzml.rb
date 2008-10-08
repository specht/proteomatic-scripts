require 'include/proteomatic'
require 'fileutils'

class Raw2MzXML < ProteomaticScript
	def run()
		ls_TempOutPath = tempFilename('raw-to-mzml')
		FileUtils.mkpath(ls_TempOutPath)
		@output.each do |ls_InPath, ls_OutPath|
			# clean up temp dir
			FileUtils::rm_rf(File::join(ls_TempOutPath, '*'))
			
			print "#{File.basename(ls_InPath)}: "
			
			# call ReAdW
			ls_Command = "#{ExternalTools::binaryPath('pwiz.msconvert')} #{@mk_Parameters.commandLineFor('pwiz.msconvert')} \"#{ls_InPath}\" -o \"#{ls_TempOutPath}\""

			print 'converting'
			$stdout.flush
			
			begin
				lk_Process = IO.popen(ls_Command)
				lk_Process.read
			rescue StandardError => e
				puts 'Error: There was an error while executing msconvert.'
				exit 1
			end

=begin			
			ls_OldDir = Dir::pwd()
			
			ls_7ZipPath = ExternalTools::binaryPath('7zip.7zip')
			Dir.chdir(ls_TempOutPath)
			
			print ', zipping'
			$stdout.flush
			
			# zip mzXML file
			ls_Command = "#{ls_7ZipPath} a -tzip #{File::basename(ls_OutPath)} #{File::basename(ls_OutPath).sub('.zip.proteomatic.part', '')} -mx5"
			begin
				lk_Process = IO.popen(ls_Command)
				lk_Process.read
			rescue StandardError => e
				puts 'Error: There was an error while executing 7zip.'
				exit 1
			end
			FileUtils::mv(File::basename(ls_OutPath), File::join('..', File::basename(ls_OutPath).sub('.proteomatic.part', '')))
			
			Dir.chdir(ls_OldDir)
			FileUtils::rm_rf(File::join(ls_TempOutPath, File::basename(ls_OutPath).sub('.zip.proteomatic.part', '')))
			puts ' - done.'
			$stdout.flush
=end			
			lk_Files = Dir[File.join(ls_TempOutPath, '*')]
			FileUtils::mv(lk_Files.first, ls_OutPath)
		end
		FileUtils::rm_rf(ls_TempOutPath)
	end
end

lk_Object = Raw2MzXML.new
