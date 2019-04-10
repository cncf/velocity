#!/usr/bin/env ruby

require 'pry'

# First file should be git.log and second devstats.log
git = {}
File.readlines(ARGV[0]).each do |line|
  git[line.strip] = true
end

devstats = {}
File.readlines(ARGV[1]).each do |line|
  devstats[line.strip] = true
end

git_miss = {}
devstats.each do |k, v|
  unless git.key?(k)
    git_miss[k] = true
  end
end

devstats_miss = {}
git.each do |k, v|
  unless devstats.key?(k)
    devstats_miss[k] = true
  end
end

git_m = git_miss.keys.sort
devstats_m = devstats_miss.keys.sort

puts "Missing in git: #{git_m.length}\n#{git_m.join("\n")}" unless git_m == ''
puts "Missing in devstats: #{devstats_m.length}\n#{devstats_m.join("\n")}" unless devstats_m == ''
