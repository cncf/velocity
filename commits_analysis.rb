require 'csv'
require 'pry'
require './comment'
require 'to_regexp'

def analyse_commits(commits)
  max_len = 0
  len = commits.min_by(&:length).length
  (1..len).each do |i|
    str = commits.first[0..i]
    differ = false
    commits.each do |commit|
      curr = commit[0..i]
      unless curr == str
        differ = true
        break
      end
    end
    # puts "Len = #{i}/#{len}, differ = #{differ}"
    break if differ
    max_len = i
  end
  n = commits.map { |commit| commit[0..max_len] }.uniq.count
  # Make len=5 minimum to consider bot
  n = 0 if n < 5
  [max_len, max_len > 0 ? commits[0][0..max_len] : '']
end


def max_substring_analysis(commits)
  # commits = commits[0..10000]
  subs = {}
  min_n = 20
  max_n = 40
  every_nth = 4
  n_commits = commits.length
  commits.each_with_index do |commit, idx|
    puts "#{idx}/#{n_commits}" if idx % 100 == 0
    len = commit.length
    len = max_n if len > max_n
    (min_n..len).each do |clen|
      next if clen % every_nth > 0
      iters = len - clen
      (0..iters).each do |i|
        ss = commit[i..i+clen]
        subs[ss] = true
      end
    end
  end

  subs = subs.keys.sort
  n_subs = subs.length
  occ = {}
  subs.each_with_index do |sub, idx|
    hit = 0
    commits.each do |commit|
      hit += 1 if commit.include?(sub)
    end
    puts "#{idx}/#{n_subs}" if idx % 1000 == 0
    occ[sub] = hit
  end
  arr = []
  occ.each { |k,v| arr << [k, v] }
  arr = arr.sort_by { |row| -row[1] }
  binding.pry
end

def commits_analysis(fin, fcfg)
  # arr[i][2].map { |row| row['name'] }.uniq
  # arr[i][2].map { |row| row['email'] }.uniq
  # arr[0][2].map { |row| "#{row['email']} #{row['name']}" }.uniq 
  # arr[i][2]

  # skip emails, names, regexps
  # skip_emails,skip_names,skip_regexps
  skip_emails = {}
  skip_names = {}
  skip_regexps = {}
  CSV.foreach(fcfg, headers: true) do |row|
    next if is_comment row
    h = row.to_h
    emails = h['skip_emails']
    names = h['skip_names']
    regexps = h['skip_regexps']
    emails.split(',').each { |email| skip_emails[email] = true }
    names.split(',').each { |name| skip_names[name] = true }
    regexps.split(';;;').each { |regexp| skip_regexps[regexp.to_regexp] = true }
  end
  skip_emails = skip_emails.keys.sort
  skip_names = skip_names.keys.sort
  skip_regexps = skip_regexps.keys

  # email,name,hash,subject
  authors = {}
  emails = {}
  names = {}
  all_commits = []
  nc = 0
  CSV.foreach(fin, headers: true) do |row|
    next if is_comment row
    h = row.to_h
    email = h['email']
    name = h['name']
    next unless email && name
    emails[email] = true
    names[name] = true
    authors[email] = {} unless authors.key? email
    authors[email][name] = [] unless authors[email].key? name
    authors[email][name] << h
    all_commits << h
    nc += 1
  end
  emails = emails.keys.sort.uniq
  names = names.keys.sort.uniq

  # Exclude commit with format:
  # Roll src/third_party/skia/ da4545bfc..3e7cddaf3 (1 commit)
  # Update V8 to version 5.6.124.1 (cherry-pick).
  # Update V8 to version 5.6.124.2
  # Roll src/third_party/catapult/ 5592ae343..b367d4648 (3 commits)
  # Roll src/third_party/pdfium/ 1629f609d..350d2d904 (1 commit)
  puts "All commits: #{nc}"
  arr = []
  authors.each do |email, data|
    # puts "email: #{email}, names: #{data.keys.count}"
    commits = []
    data.each do |name, comms|
      # puts "name: #{email}, commits: #{comms.count}"
      comms.each { |commit| commits << commit }
    end
    # puts "commits: #{commits.count}"
    arr << [email, commits.count, commits]
  end
  arr = arr.sort_by { |row| -row[1] }

  indices = []
  arr.each_with_index do |row, idx|
    commits = row[2].map { |commit| commit['subject'] }.sort.uniq
    n_commits = commits.length
    # Do not process commits if less than 5
    next if n_commits < 5
    n, str = analyse_commits commits
    puts "##{idx},#{n},#{commits.length}: #{str}" if n > 0
    indices << [idx, n, commits.length, str] if n > 0
  end

  # Filter by defined email/name/regexp
  filtered_commits = []
  skipped_commits = []
  all_commits.each do |commit|
    if skip_emails.include?(commit['email']) || skip_names.include?(commit['name'])
      skipped_commits << commit
      next
    end
    match_regexp = false
    skip_regexps.each do |regexp|
      match_regexp = true if commit['subject'].match(regexp)
    end
    if match_regexp
      skipped_commits << commit
      next
    end
    filtered_commits << commit
  end

  # Output
  n_authors = filtered_commits.map { |commit| commit['email'] }.uniq.count
  n_hashes = filtered_commits.map { |commit| commit['hash'] }.uniq.count
  puts "After filtering: authors: #{n_authors}, commits: #{n_hashes}"
  puts 'arr[0..20].map.with_index { |a,i| [i,a[0], a[1], a[2][0..20]] }'

  max_substring_analysis all_commits.map { |commit| commit['subject'].downcase.strip }.sort.uniq

  binding.pry
end

if ARGV.size < 2
  puts "Missing arguments: data/data_chromium_commits.csv map/skip_commits.csv"
  exit(1)
end

commits_analysis(ARGV[0], ARGV[1])
