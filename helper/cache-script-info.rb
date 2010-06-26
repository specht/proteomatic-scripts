require 'fileutils'

# GO TO THE CORRECT DIRECTORY, NO MATTER WHAT!
Dir::chdir(File::join(Dir::pwd, File::dirname($0), '..'))

require 'yaml'
require 'include/ruby/proteomatic'

#extensions = ['.rb', '.php', '.py', '.pl']

extensions = ['.rb']
allScripts = []
extensions.each do |ext|
    allScripts += Dir["*#{ext}"]
end

allScripts.reject! { |x| x.include?('.defunct.') }
allScripts.sort!

results = Hash.new

puts "Caching ---yamlInfo --short for #{allScripts.size} scripts..."

allScripts.each_with_index do |script, index|
    descriptionPath = "include/properties/#{script.sub('.defunct.', '.').sub('.rb', '')}.yaml"
    FileUtils::mkpath(File::join(File::dirname(descriptionPath), '..', '..', 'cache'))
    
    object = ProteomaticScript.new(descriptionPath, true)
    if (object.configOk())
        yamlInfo = object.yamlInfo(true)
        if yamlInfo[0, 11] == '---yamlInfo'
            File::open(File::join(File::dirname(descriptionPath), '..', '..', 'cache', script + '.short.yamlinfo'), 'w') do |f|
                f.puts yamlInfo
            end
        end
    end
    
    object = ProteomaticScript.new(descriptionPath, true)
    if (object.configOk())
        yamlInfo = object.yamlInfo(false)
        if yamlInfo[0, 11] == '---yamlInfo'
            File::open(File::join(File::dirname(descriptionPath), '..', '..', 'cache', script + '.long.yamlinfo'), 'w') do |f|
                f.puts yamlInfo
            end
        end
    end
end
