# GO TO THE CORRECT DIRECTORY, NO MATTER WHAT!
Dir::chdir(File::join(Dir::pwd, File::dirname($0), '..'))

require 'yaml'
require './include/ruby/externaltools'

$stdout.sync = true
$stderr.sync = true

deps = ARGV.dup
if deps.include?('--extToolsPath')
    i = deps.index('--extToolsPath')
    ExternalTools::setExtToolsPath(deps[i + 1])
    deps.delete_at(i)
    deps.delete_at(i)
end

deps.each do |dep|
    if ExternalTools::installed?(dep, 'helper/languages/')
        puts ExternalTools::binaryPath(dep.split('.').last + '.' + dep.split('.').last, false, 'helper/languages/lang.')
    end
end
