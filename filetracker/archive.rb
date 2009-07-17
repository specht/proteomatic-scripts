require 'yaml'

t = Time.now
timestamp = t.strftime("%Y-%m")

file = File.open("filetracker-reports-#{timestamp}.yaml", "a")

  if item
    item = File.open(" ", "a").each  do |file|
    YAML.dump (array, item)
    item.close
  end

YAML::load(File.open(" ", "r"))