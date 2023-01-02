#!/usr/bin/env ruby
require 'json'
require 'pry'

def merge_forks(ftarget, fsource)
  dbg = !ENV['DEBUG'].nil?
  target_fork_data = {}
  source_fork_data = {}
  begin
    data = JSON.parse File.read ftarget
    data.each do |row|
      repo = row[0]
      is_fork = row[1]
      target_fork_data[repo] = is_fork
    end
    data = JSON.parse File.read fsource
    data.each do |row|
      repo = row[0]
      is_fork = row[1]
      source_fork_data[repo] = is_fork
    end
  rescue => err
    STDERR.puts [err.class, err]
  end
  missing = 0
  nils = 0
  source_fork_data.each do |repo, is_fork|
    if !target_fork_data.key?(repo) and !is_fork.nil?
      target_fork_data[repo] = is_fork
      missing += 1
      next
    end
    if target_fork_data.key?(repo) and target_fork_data[repo].nil? and !is_fork.nil?
      target_fork_data[repo] = is_fork
      nils += 1
    end
  end
  if missing > 0 or nils > 0 
    puts "Added #{missing} #{ftarget} <- #{fsource}" if missing > 0
    puts "Updated #{nils} nils #{ftarget} <- #{fsource}" if nils > 0
    pretty = JSON.pretty_generate target_fork_data
    File.write ftarget, pretty
    puts "Saved"
  end
  exit 1
end

if ARGV.size < 2
  # targed will get all keys from source
  puts "Missing arguments: target.csv source.csv"
  exit(1)
end

merge_forks(ARGV[0], ARGV[1])
