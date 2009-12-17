require 'rbconfig'

$gs_Ruby = File.join(Config::CONFIG["bindir"], Config::CONFIG["ruby_install_name"]) 

puts "Using #{$gs_Ruby}..."


def testCommand(as_Path, as_Command)
	ls_Command = "#{$gs_Ruby} -C#{File::dirname(as_Path)} #{File::basename(as_Path)} #{as_Command} > run-tests.temp.txt"
	ls_Output = `#{ls_Command}`
	if $? != 0
		puts ls_Output
		puts "FAIL on #{as_Command} (#{$?})"
		exit
	end
end

puts 'Checking descriptions...'
lk_Descriptions = Dir[File::join(File::dirname($0), '../include/properties/**', '*.yaml')]
lk_Descriptions.each do |ls_Path|
	ls_Content = File::read(ls_Path)
	if ls_Content.include?("\t")
		puts "YAML error: #{ls_Path} contains one or more tabs."
		exit 1
	end
end

puts 'Checking scripts...'
lk_Scripts = Dir[File::join(File::dirname($0), '..', '*.rb')]
lk_Scripts.sort.each do |ls_Path|
	next if ls_Path.include?('.defunct.')
	print "#{File::basename(ls_Path)}: "
	testCommand(ls_Path, '--help')
	testCommand(ls_Path, '---yamlInfo')
	testCommand(ls_Path, '--resolveDependencies')
	puts 'ok.'
end
