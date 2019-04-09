require 'csv'
require 'pry'
require './comment'

def add_linux(fout, fdata, rfrom, rto)

  # org,repo,from,to,changesets,additions,removals,authors,emails
  data = {}
  CSV.foreach(fdata, headers: true) do |row|
    next if is_comment row
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
  # simulate N distinct authors as returned from BigQuery
  # linux['authors'] = linux['authors'].times.map { |i| i }.join(',')
  linux['authors'] = "=#{linux['authors']}"
  linux['authors_alt1'] = linux['authors']
  linux['authors_alt2'] = linux['authors'].split(',').uniq.count

  # fout
  ks = %w(org repo activity comments prs commits issues authors_alt2 authors_alt1 authors pushes)
  checked = false
  rows = []
  CSV.foreach(fout, headers: true) do |row|
    next if is_comment row
    h = row.to_h
    if !checked && h.keys != ks
      puts "CSV file to update #{fout} have different header: #{h.keys} than required #{ks}"
      return
    else
      checked = true
    end

    if h['org'] == 'torvalds' && h['repo'] == 'torvalds/linux'
      nh = {}
      h.each do |k, v|
        v = v.split(',').count if ['authors', 'authors_alt1'].include?(k)
        nh[k] = v
      end
      puts "CSV file already contains linux: #{nh}"
      return
    end

    rows << h
  end

  linux_row = {
    'org' => 'torvalds',
    'repo' => 'torvalds/linux',
    'activity' => linux['changesets'] + linux['emails'],
    'comments' => linux['emails'],
    'prs' => linux['new_emails'],
    'commits' => linux['changesets'],
    'issues' => linux['new_emails'],
    'authors_alt2' => linux['authors_alt2'],
    'authors_alt1' => linux['authors_alt1'],
    'authors' => linux['authors'],
    'pushes' => linux['pushes']
  }

  CSV.open(fout, "w", headers: ks) do |csv|
    csv << ks
    csv << linux_row
    rows.each do |row|
      csv << row
    end
  end

  nh = {}
  linux_row.each do |k, v|
    v = v.split(',').count if ['authors', 'authors_alt1'].include?(k)
    nh[k] = v
  end
  puts "Added Linux: #{nh}"

end

if ARGV.size < 4
  puts "Missing arguments: datafile.csv linuxdata.csv period_from period_to"
  exit(1)
end

add_linux(ARGV[0], ARGV[1], ARGV[2], ARGV[3])
