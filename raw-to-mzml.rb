require 'include/proteomatic'
require 'fileutils'

class Raw2MzXML < ProteomaticScript
	def run()
		ls_TempOutPath = tempFilename('raw-to-mzml', Dir::tmpdir)
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

			ls_OldDir = Dir::pwd()
			
			ls_7ZipPath = ExternalTools::binaryPath('7zip.7zip')
			Dir.chdir(ls_TempOutPath)
			
			print ', zipping'
			$stdout.flush
			
			# zip mzXML file
			lk_Files = Dir['*']
			ls_Command = "#{ls_7ZipPath} a -tzip #{lk_Files.first + '.zip'} #{lk_Files.first} -mx5"
			begin
				lk_Process = IO.popen(ls_Command)
				lk_Process.read
			rescue StandardError => e
				puts 'Error: There was an error while executing 7zip.'
				exit 1
			end
			FileUtils::rm_f(lk_Files.first)
			
			Dir.chdir(ls_OldDir)
			
			lk_Files = Dir[File.join(ls_TempOutPath, '*')]
			FileUtils::mv(lk_Files.first, ls_OutPath)
			puts ' - done.'
			$stdout.flush
		end
		FileUtils::rm_rf(ls_TempOutPath)
	end
end

lk_Object = Raw2MzXML.new
