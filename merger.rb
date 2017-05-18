require 'csv'
require 'pry'

def merger(fmerge, fdata)
  # Repo --> data mapping (from file to get data from)
  repos = {}
  CSV.foreach(fdata, headers: true) do |row|
    h = row.to_h
    repo = h['repo'].strip
    repos[repo] = h
  end

  # File to update
  updated = []
  repos2 = {}
  CSV.foreach(fmerge, headers: true) do |row|
    h = row.to_h
    repo = h['repo'].strip
    if repos.key? repo
      old = h
      new = repos[repo]
      old.each do |k, v|
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
  puts "Updated #{updated.count} values"

  # Add values that are not present 
  repos.each { |repo, data| repos2[repo] = data unless repos2.key?(repo) }

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
