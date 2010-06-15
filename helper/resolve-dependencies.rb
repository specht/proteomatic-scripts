require 'yaml'
require 'include/ruby/externaltools'

ARGV.each do |dep|
    ExternalTools::install(dep) unless ExternalTools::installed?(dep)
end
