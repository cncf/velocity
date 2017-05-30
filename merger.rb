require 'csv'
require 'pry'
require './comment'

def merger(fmerge, fdata)
  # Repo --> data mapping (from file to get data from)
  repos = {}
  CSV.foreach(fdata, headers: true) do |row|
    next if is_comment row
    h = row.to_h
    repo = h['repo'].strip
    repos[repo] = h
  end

  # File to update
  updated = []
  repos2 = {}
  higher = 0
  CSV.foreach(fmerge, headers: true) do |row|
    next if is_comment row
    h = row.to_h
    repo = h['repo'].strip
    if repos.key? repo
      old = h
      new = repos[repo]
      old.each do |k, v|
        # binding.pry if v.to_i.to_s == v.to_s
        if v.to_i.to_s == v.to_s && v.to_i > new[k].to_i
          puts "Not updating #{k}, current value #{v} higher than new value #{new[k]}"
          higher += 1
          next
        end
        if v != new[k]
          h[k] = new[k]
          updated << [repo, k, v, new[k]]
        end
      end
    end
    repos2[repo] = h
  end

  # Some debug output
  #updated.each do |item|
  #  puts "Updated repo: #{item[0]}, #{item[1]} changed from '#{item[2]}' to '#{item[3]}'"
  #end

  # Add values that are not present 
  added = 0
  repos.each do |repo, data|
    unless repos2.key?(repo)
      repos2[repo] = data
      added += 1
    end
  end
  puts "Updated #{updated.count} values" if updated.count > 0
  puts "Added #{added} values" if added > 0
  puts "Skipped #{higher} values because current values were higher than new" if higher > 0

  # Write changes back to file to update
  hdr = repos2.values.first.keys
  CSV.open(fmerge, "w", headers: hdr) do |csv|
    csv << hdr
    repos2.values.each { |repo| csv << repo }
  end
end

if ARGV.size < 2
  puts "Missing arguments: file_to_merge.csv file_to_get_data_from.csv"
  exit(1)
end

merger(ARGV[0], ARGV[1])
