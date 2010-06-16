require 'yaml'
require 'include/ruby/proteomatic'

result = Hash.new

ARGV.each do |script|
    descriptionPath = "include/properties/#{script.sub('.defunct.', '.').sub('.rb', '')}.yaml"
    next unless File::exists?(descriptionPath)
    object = ProteomaticScript.new(descriptionPath)
    next unless object.configOk()
    result.merge!(object.unresolvedDependencies())
end

puts result.to_yaml
