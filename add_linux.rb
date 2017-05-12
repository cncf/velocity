require 'csv'
require 'pry'

def add_linux(fout, fdata, rfrom, rto)

  # org,repo,from,to,changesets,additions,removals,authors,emails
  data = {}
  CSV.foreach(fdata, headers: true) do |row|
    h = row.to_h
    from = h['from'].strip
    to = h['to'].strip
    h.each do |k, v|
      h[k] = v.to_i if v.to_i.to_s ==v 
    end
    data[[from, to]] = h
  end

  unless data.key? [rfrom, rto]
    puts "Data range not found in #{fdata}: #{rfrom} - #{rto}"
    return
  end

  linux = data[[rfrom, rto]]

  # fout
  ks = %w(org repo activity comments prs commits issues authors)
  checked = false
  rows = []
  CSV.foreach(fout, headers: true) do |row|
    h = row.to_h
    if !checked && h.keys != ks
      puts "CSV file to update #{fout} have different header: #{h.keys} than required #{ks}"
      return
    else
      checked = true
    end

    if h['org'] == 'torvalds' && h['repo'] == 'torvalds/linux'
      puts "CSV file already contains linux: #{h}"
      return
    end

    rows << h
  end

  linux_row = {
    'org' => 'torvalds',
    'repo' => 'torvalds/linux',
    'activity' => linux['changesets'] + linux['emails'],
    'comments' => linux['emails'],
    'prs' => linux['emails'] / 4,
    'commits' => linux['changesets'],
    'issues' => linux['emails'] / 4,
    'authors' => linux['authors']
  }

  CSV.open(fout, "w", headers: ks) do |csv|
    csv << ks
    csv << linux_row
    rows.each do |row|
      csv << row
    end
  end

end

if ARGV.size < 4
  puts "Missing arguments: datafile.csv linuxdata.csv period_from period_to"
  exit(1)
end

add_linux(ARGV[0], ARGV[1], ARGV[2], ARGV[3])
