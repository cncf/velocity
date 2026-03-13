require 'csv'
require 'pry'
require './comment'

def env_flag?(name)
  ENV[name].to_s.strip != ''
end

def summarize_value(v)
  return v if v.nil?
  s = v.to_s
  if s.start_with?('=') && s[1..].to_i.to_s == s[1..]
    return s[1..].to_i
  end
  if s.include?(',')
    return s.split(',').reject(&:empty?).count
  end
  s
end

def linux_row?(h)
  org = (h['org'] || '').strip
  repo = (h['repo'] || '').strip
  repo == 'torvalds/linux' || (org == 'torvalds' && repo == 'linux')
end


def add_linux(fout, fdata, rfrom, rto)
  overwrite = env_flag?('OVERWRITE')
  skip_commits = env_flag?('SKIP_COMMITS')

  # org,repo,from,to,changesets,additions,removals,authors,emails
  data = {}
  CSV.foreach(fdata, headers: true) do |row|
    next if is_comment row
    h = row.to_h
    from = h['from'].strip
    to = h['to'].strip
    h.each do |k, v|
      next if v.nil?
      h[k] = v.to_i if v.to_i.to_s == v
    end
    data[[from, to]] = h
  end

  unless data.key? [rfrom, rto]
    puts "Data range not found in #{fdata}: #{rfrom} - #{rto}"
    return
  end

  linux = data[[rfrom, rto]]
  linux_authors = linux['authors'].to_i
  # simulate N distinct authors as returned from BigQuery
  # linux['authors'] = linux['authors'].times.map { |i| i }.join(',')
  linux['authors'] = "=#{linux_authors}"
  linux['authors_alt1'] = linux['authors']
  # linux['authors_alt2'] = linux['authors'].split(',').uniq.count
  linux['authors_alt2'] = linux_authors

  # fout
  # ks = %w(org repo activity comments prs commits issues authors_alt2 authors_alt1 authors pushes)
  ks = %w(org repo activity comments prs commits issues pushes authors_alt2 authors_alt1 authors author_idents)
  checked = false
  rows = []
  existing_linux = nil
  CSV.foreach(fout, headers: true, liberal_parsing: true) do |row|
    next if is_comment row
    h = row.to_h
    if !checked && h.keys != ks
      puts "CSV file to update #{fout} have different header: #{h.keys} than required #{ks}"
      return
    else
      checked = true
    end

    if linux_row?(h)
      nh = {}
      h.each do |k, v|
        nh[k] = summarize_value(v)
      end
      if overwrite
        puts "CSV file already contains linux, overwriting: #{nh}"
        existing_linux = h
        next
      else
        puts "CSV file already contains linux: #{nh}"
        return
      end
    end

    rows << h
  end

  linux_row = {
    'org' => 'torvalds',
    'repo' => 'torvalds/linux',
    'comments' => linux['new_emails'],
    'prs' => linux['new_emails'],
    'issues' => linux['new_emails'],
    'pushes' => linux['pushes'],
    'commits' => linux['changesets'],
    'authors_alt2' => linux['authors_alt2'],
    'authors_alt1' => linux['authors_alt1'],
    'authors' => linux['authors'],
    'author_idents' => '-'
  }

  if skip_commits
    if existing_linux.nil?
      puts 'SKIP_COMMITS=1 requested but no existing linux row found, using linux CSV commits/authors values'
    else
      %w(commits authors_alt2 authors_alt1 authors author_idents).each do |k|
        linux_row[k] = existing_linux[k]
      end
    end
  end

  linux_row['activity'] = linux_row['commits'].to_i + 3 * linux['new_emails'] + linux['pushes'].to_i

  CSV.open(fout, 'w', headers: ks) do |csv|
    csv << ks
    csv << linux_row
    rows.each do |row|
      csv << row
    end
  end

  nh = {}
  linux_row.each do |k, v|
    nh[k] = summarize_value(v)
  end
  puts "Added Linux: #{nh}"

end

if ARGV.size < 4
  puts 'Missing arguments: datafile.csv linuxdata.csv period_from period_to'
  exit(1)
end

add_linux(ARGV[0], ARGV[1], ARGV[2], ARGV[3])
