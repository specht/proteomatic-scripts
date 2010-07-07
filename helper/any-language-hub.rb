require 'include/ruby/proteomatic'
require 'yaml'

# This is the hub to any other scripting language. Call with 
# [path to YAML file] [original command line parameters]

descriptionPath = ARGV.shift

object = ProteomaticScript.new(descriptionPath, true)
if (object.configOk())
    yamlInfo = object.yamlInfo(true)
    puts yamlInfo
end
