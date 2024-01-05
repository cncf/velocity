#!/usr/bin/env ruby

require 'csv'
# require 'pry'

if ENV['OUT'].nil?
  puts "Specify output file via OUT=filename.csv"
  exit
end
ofn = ENV['OUT']
mmi = {}
all_lines = 0
ARGV.each_with_index do |fn, i|
  puts "#{i+1}) file: #{fn}"
  lines = 0
  CSV.foreach(fn, headers: true) do |row|
    ky = row['repo']
    mmi[ky] = [] unless mmi.key?(ky)
    mmi[ky] << row.to_h
    lines += 1
  end
  puts "#{i+1}) #{lines} lines, input map has now #{mmi.length} records"
  all_lines += lines
end
puts "all lines: #{all_lines}, records: #{mmi.length}"

mmo = {}
single = multi = replaced = 0
sumk = ['activity', 'comments', 'prs', 'commits', 'issues', 'pushes']
mmi.each do |k, v|
  w = {}
  w['org'] = v[0]['org']
  w['repo'] = v[0]['repo']
  sumk.each do |ky|
    w[ky] = 0
  end
  # authors: emails string , separated
  # authors_alt1: names string , separated
  # authors_alt2: number (value as string)
  wauth = 0
  wemails = {}
  wnames = {}
  v.each do |r|
    sumk.each do |ky|
      w[ky] += r[ky].to_i
    end
    # authors
    remails = r['authors'].split(',')
    remails.each do |email|
      wemails[email] = true
    end
    # authors_alt1
    rnames = r['authors_alt1'].split(',')
    rnames.each do |name|
      wnames[name] = true
    end
    # authors_alt2
    auth = r['authors_alt2'].to_i
    wauth = auth if auth > wauth
  end
  w['authors'] = wemails.keys.join(',')
  w['authors_alt1'] = wnames.keys.join(',')
  # authors_alt2 is just MAX so it is the ONLY column that will NOT be accurate
  w['authors_alt2'] = wauth
  nemails = wemails.keys.length
  nnames = wnames.keys.length
  w['authors_alt2'] = nemails if nemails > w['authors_alt2']
  w['authors_alt2'] = nnames if nnames > w['authors_alt2']
  replaced += 1 unless wauth == w['authors_alt2']
  mmo[k] = w
  if v.length == 1
    single += 1
  else
    multi += 1
  end
end
puts "output to: #{ofn}"
puts "output records: #{mmo.length}, single: #{single}, merged: #{multi}, authors from unique count: #{replaced}"

hdr = %w(org repo activity comments prs commits issues authors_alt2 authors_alt1 authors pushes)
data = []
mmo.each do |_, row|
  data << [-row['authors_alt2'].to_i, row]
end
data = data.sort_by { |row| row[0] }
CSV.open(ofn, 'w', headers: hdr) do |csv|
  csv << hdr
  data.each do |row|
    csv << row[1]
  end
end
