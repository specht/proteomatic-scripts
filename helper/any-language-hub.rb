$: << File::join(File::dirname($0), '..')

require 'include/ruby/proteomatic'
require 'yaml'

# This is the hub to any other scripting language. Call with 
# [path to control file] [original command line parameters]

controlFilePath = ARGV.shift
object = ProteomaticScript.new(nil, false, controlFilePath)
