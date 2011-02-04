# check whether all external tools and languages are available

require 'fileutils'

# GO TO THE CORRECT DIRECTORY, NO MATTER WHAT!
Dir::chdir(File::join(Dir::pwd, File::dirname($0), '..'))

require 'yaml'
require './include/ruby/proteomatic'
require './include/ruby/externaltools'

if ARGV.include?('--extToolsPath')
    ExternalTools::setExtToolsPath(ARGV[ARGV.index('--extToolsPath') + 1])
end

deps = []

Dir['include/cli-tools-atlas/packages/ext.*.yaml'].each do |path|
    next unless File::basename(path).split('.').size == 3
    dep = File::basename(path).split('.')[0, 2].join('.')
    deps << dep
end

Dir['helper/languages/lang.*.yaml'].each do |path|
    next unless File::basename(path).split('.').size == 3
    dep = File::basename(path).split('.')[0, 2].join('.')
    deps << dep
end

deps.each do |dep|
    begin
        ExternalTools::checkAllDownloads(dep)
    rescue StandardError => e
        puts "ERROR: Something is wrong with #{dep}..."
        puts e
    end
end
