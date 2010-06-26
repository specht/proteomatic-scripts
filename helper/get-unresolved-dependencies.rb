# GO TO THE CORRECT DIRECTORY, NO MATTER WHAT!
Dir::chdir(File::join(Dir::pwd, File::dirname($0), '..'))

require 'yaml'
require 'include/ruby/proteomatic'

result = Hash.new

scripts = ARGV.dup
if scripts.include?('--extToolsPath')
    i = scripts.index('--extToolsPath')
    scripts.delete_at(i)
    scripts.delete_at(i)
end

scripts.each do |script|
    descriptionPath = "include/properties/#{script.sub('.defunct.', '.').sub('.rb', '')}.yaml"
    next unless File::exists?(descriptionPath)
    object = ProteomaticScript.new(descriptionPath, true)
    next unless object.configOk()
    result.merge!(object.unresolvedDependencies())
end

puts result.to_yaml
