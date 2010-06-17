# GO TO THE CORRECT DIRECTORY, NO MATTER WHAT!
Dir::chdir(File::join(Dir::pwd, File::dirname($0), '..'))

require 'yaml'
require 'include/ruby/externaltools'

flushThread = Thread.new do
    while true
        $stdout.flush
        $stderr.flush
        sleep 1.0
    end
end


deps = ARGV.dup
if deps.include?('--extToolsPath')
    i = deps.index('--extToolsPath')
    ExternalTools::setExtToolsPath(deps[i + 1])
    deps.delete_at(i)
    deps.delete_at(i)
end

deps.each do |dep|
    ExternalTools::install(dep) unless ExternalTools::installed?(dep)
end
