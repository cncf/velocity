#!/usr/bin/env ruby

# require 'pry'
require 'yaml'

if ENV['PG_PASS'].nil?
  puts "You need to set PG_PASS=..."
  exit 1
end

from = ARGV[0]
to = ARGV[1]

if from.nil? || to.nil?
  puts "You need to set provide dt-from and dt-to arguments"
  exit 2
end
  
data = YAML.load_file '/root/dev/go/src/github.com/cncf/devstats/projects.yaml'
`echo 'project,key,value' > "data/data_cncf_update_#{from}_#{to}.csv"`
data['projects'].each do |project|
  next if project[0] == 'all'
  db = project[1]['psql_db']
  name = project[1]['name']
  disabled = project[1]['disabled']
  next if disabled
  puts "#{db} -> #{name}"
  #`./shells/get_git_commits_count.sh "#{db}" "#{from}" "#{to}"`
  `./shells/get_git_commits_count_from_all.sh "#{name}" "#{from}" "#{to}"`
  commits=`cat commits.txt`
  puts "#{name} commits: #{commits}"
  `echo -n "#{name},commits,#{commits}" >> "data/data_cncf_update_#{from}_#{to}.csv"`
end

