# GO TO THE CORRECT DIRECTORY, NO MATTER WHAT!
Dir::chdir(File::join(Dir::pwd, File::dirname($0), '..'))

require 'yaml'
require 'include/ruby/proteomatic'

#extensions = ['.rb', '.php', '.py', '.pl']

if ARGV.include?('--interactive')
    while true
        STDOUT.puts "NEXT PLEASE"
        STDOUT.flush
        script = STDIN.gets.strip
        break if script.empty?
        descriptionPath = "include/properties/#{script.sub('.defunct.', '.').sub('.rb', '')}.yaml"
        unless File::exists?(descriptionPath)
            descriptionPath = File::join(File::dirname(script), "include/properties/#{File::basename(script).sub('.defunct.', '.').sub('.rb', '')}.yaml")
        end
        begin
            object = ProteomaticScript.new(descriptionPath)
            if object.configOk()
                yamlInfo = object.yamlInfo(true)
                if yamlInfo[0, 11] == '---yamlInfo'
                    STDOUT.puts yamlInfo
                end
            end
        rescue
            STDOUT.puts "Error: Unable to load script: #{script}"
        end
        STDOUT.flush
    end
    exit
end

allScripts = Array.new

if (ARGV.empty?)
    extensions = ['.rb']
    allScripts = []
    extensions.each do |ext|
        allScripts += Dir["*#{ext}"]
    end
else
    allScripts = ARGV
end

allScripts.reject! { |x| x.include?('.defunct.') }
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
