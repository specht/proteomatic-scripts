require 'yaml'
require 'include/ruby/proteomatic'

#extensions = ['.rb', '.php', '.py', '.pl']
extensions = ['.rb']
allScripts = []
extensions.each do |ext|
    allScripts += Dir["*#{ext}"]
end
allScripts.reject { |x| x.include?('.defunct.') }
allScripts.sort!

# allScripts.each do |script|
#     puts script
#     info = `ruby1.9.1 \"#{script}\" ---yamlInfo --short`
#     puts info
# end
# exit


results = Hash.new

allScripts.each_with_index do |script, index|
    STDERR.puts "PROGRESS #{index + 1} of #{allScripts.size}"
    STDERR.flush
    descriptionPath = "include/properties/#{script.sub('.defunct.', '.').sub('.rb', '')}.yaml"
    object = ProteomaticScript.new(descriptionPath)
    next unless object.configOk()
    yamlInfo = object.yamlInfo(true)
    next unless yamlInfo[0, 11] == '---yamlInfo'
    yamlInfo.sub!('---yamlInfo', '')
    yamlInfo.strip!
    results[script] = YAML::load(yamlInfo)
end

STDOUT.puts results.to_yaml
