require 'csv'
require 'pry'
require './comment'

def add_external(fout, fdata, rfrom, rto, eorg, erepo)
  # org,repo,from,to,activity,comments,prs,commits,issues,authors
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

  external = data[[rfrom, rto]]
  # simulate N distinct authors as returned from BigQuery
  external['authors'] = external['authors'].times.map { |i| i }.join(',')
  external['authors_alt1'] = external['authors']
  external['authors_alt2'] = external['authors'].split(',').uniq.count

  # fout
  ks = %w(org repo activity comments prs commits issues authors_alt2 authors_alt1 authors)
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

    if h['org'] == eorg && h['repo'] == erepo
      nh = {}
      h.each do |k, v|
        v = v.split(',').count if ['authors', 'authors_alt1'].include?(k)
        nh[k] = v
      end
      puts "CSV file already contains #{eorg} #{erepo}: #{nh}"
      return
    end

    rows << h
  end

  # org,repo,from,to,activity,comments,prs,commits,issues,authors
  external_row = {
    'org' => eorg,
    'repo' => erepo,
    'activity' => external['activity'],
    'comments' => external['comments'],
    'prs' => external['prs'],
    'commits' => external['commits'],
    'issues' => external['issues'],
    'authors_alt2' => external['authors_alt2'],
    'authors_alt1' => external['authors_alt1'],
    'authors' => external['authors']
  }

  CSV.open(fout, "w", headers: ks) do |csv|
    csv << ks
    csv << external_row
    rows.each do |row|
      csv << row
    end
  end

  nh = {}
  external_row.each do |k, v|
    v = v.split(',').count if ['authors', 'authors_alt1'].include?(k)
    nh[k] = v
  end
  puts "Added row for #{eorg} #{erepo}: #{nh}"

end

if ARGV.size < 6
  puts "Missing arguments: datafile.csv external_data.csv period_from period_to org_name repo_name"
  exit(1)
end

add_external(ARGV[0], ARGV[1], ARGV[2], ARGV[3], ARGV[4], ARGV[5])
