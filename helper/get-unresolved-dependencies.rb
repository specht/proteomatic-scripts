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
    extension = script.downcase
    descriptionPath = "include/properties/#{script.sub('.defunct.', '.').sub('.rb', '')}.yaml"
    descriptionPath = "include/properties/#{script.sub('.defunct.', '.').sub('.php', '')}.yaml" if extension[-4, 4] == '.php'
    descriptionPath = "include/properties/#{script.sub('.defunct.', '.').sub('.php4', '')}.yaml" if extension[-5, 5] == '.php4'
    descriptionPath = "include/properties/#{script.sub('.defunct.', '.').sub('.php5', '')}.yaml" if extension[-5, 5] == '.php5'
    descriptionPath = "include/properties/#{script.sub('.defunct.', '.').sub('.py', '')}.yaml" if extension[-3, 3] == '.py'
    descriptionPath = "include/properties/#{script.sub('.defunct.', '.').sub('.pl', '')}.yaml" if extension[-3, 3] == '.pl'
    next unless File::exists?(descriptionPath)
    object = ProteomaticScript.new(descriptionPath, true)
    next unless object.configOk()
    result.merge!(object.unresolvedDependencies())
end

puts result.to_yaml
