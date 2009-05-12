require 'rbconfig'

$gs_Ruby = File.join(Config::CONFIG["bindir"], Config::CONFIG["ruby_install_name"]) 

puts "Using #{$gs_Ruby}..."

lk_Scripts = Dir[File::join(File::dirname($0), '..', '*.rb')]

def testCommand(as_Path, as_Command)
	ls_Command = "#{$gs_Ruby} -C#{File::dirname(as_Path)} #{File::basename(as_Path)} #{as_Command} > run-tests.temp.txt"
	ls_Output = `#{ls_Command}`
	if $? != 0
		puts ls_Output
		puts "FAIL on #{as_Command} (#{$?})"
		exit
	end
end

lk_Scripts.sort.each do |ls_Path|
	next if ls_Path.include?('.defunct.')
	print "#{File::basename(ls_Path)}: "
	testCommand(ls_Path, '--help')
	testCommand(ls_Path, '---info')
	testCommand(ls_Path, '---getParameters')
	testCommand(ls_Path, '--resolveDependencies')
	puts 'ok.'
end
