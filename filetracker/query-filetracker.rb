require 'yaml'

ARGV.each do |path|
	outPath = path + '.filetracker.txt'
	if File::exists?(outPath)
		puts "Error: #{outPath} already exists, skipping file."
		next
	end
	File::open(outPath, 'w') do |fo|
		md5 = `md5sum \"#{path}\"`.split(' ').first
		print File::basename(path)
		puts ' ' + md5
		Dir['archive/*.yaml'].each do |archivePath|
			File::open(archivePath, 'r') do |f|
				YAML::load_documents(f) do |report|
					printThis = false
					report['files'].each do |entry|
						printThis = true if entry['md5'] == md5
						printThis = true if entry['basename'] == File::basename(path)
					end
					fo.puts report.to_yaml if printThis
				end
			end
		end
	end
end

