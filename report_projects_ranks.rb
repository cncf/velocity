require 'csv'
require 'pry'
require 'to_regexp'
require './comment'

def report_ranks(fin, fpstats, frep)
  # Read list of projects to generate statistics for
  # project
  pstats = {}
  CSV.foreach(fpstats, headers: true) do |row|
    next if is_comment row
    h = row.to_h
    proj = h['project']
    if pstats.key? proj
      puts "Project #{proj} already present in projects statistics file"
      return
    end
    pstats[proj] = true
  end

  # org,repo,activity,comments,prs,commits,issues,authors,project,url
  res = {}
  CSV.foreach(fin, headers: true) do |row|
    next if is_comment row
    h = row.to_h
    proj = h['project']
    if res.key? proj
      puts "Project #{proj} already present in projects file"
      return
    end
    res[proj] = h
  end

  # Generate list of projects
  pstats = pstats.keys.sort
  out = []
  all_projs = res.keys.sort
  pstats.each do |proj|
    if proj[0] == '/'
      puts "Matching reexp: #{proj.to_regexp}"
      projs = all_projs.select { |p| p.match(proj.to_regexp) }
      projs.each { |p| out << p }
      next
    end
    unless res[proj]
      puts "Project #{proj} not found, skipping stats"
      next
    end
    out << proj
  end
  pstats = out.sort
  puts "Generating statistics for projects: #{pstats.join(', ')}"
 
  # Generate project rank statistics
  props = nil
  stats = {}
  pstats.each do |proj|
    obj = res[proj]
    unless obj
      puts "Project #{proj} not found, aborting stats"
      return
    end
    props = obj.keys.select { |key| obj[key].to_i.to_s == obj[key].to_s } - %w(authors_alt1 authors_alt2) unless props
    props.each do |prop|
      stats[proj] = {} unless stats.key? proj
      stats[proj][prop] = res.map { |k, v| [v[prop].to_i, v] }.sort_by { |r| -r[0] }.map.with_index { |r, i| [i + 1, r[1]['project'], r[1][prop]] }.select { |r| r[1] == proj }.first
      # binding.pry if proj == 'Chromium' && prop == 'commits'
    end
  end

  File.open(frep, 'w') do |rep|
    stats.keys.sort.each do |proj|
      rep.write("#{proj}:\n")
      stats[proj].keys.sort.each do |prop|
        v = stats[proj][prop]
        rep.write("\t\##{v[0]} by #{prop} (#{v[2]})\n")
      end
      rep.write("\n")
    end
  end

  puts "Statistics done."
end

if ARGV.size < 3
  puts "Missing arguments: projects/unlimited_both.csv map/projects_statistics.csv projects/projects_ranks.txt"
  exit(1)
end

report_ranks(ARGV[0], ARGV[1], ARGV[2])
