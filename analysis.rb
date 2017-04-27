require 'csv'
require 'pry'

def analysis(fin, fout, fhint, furls, fdefmaps)
  # Repo --> Project mapping
  projects = {}
  CSV.foreach(fhint, headers: true) do |row|
    h = row.to_h
    proj = h['project'].strip
    repo = h['repo'].strip
    if projects.key?(repo) && projects[repo] != proj
      puts "Non unique entry: projects: projects['#{repo}'] = '#{projects[repo]}', new value: #{proj}"
      return
    end
    projects[repo] = proj
  end

  hdr = ['repo', 'project']
  CSV.open(fhint, "w", headers: hdr) do |csv|
    csv << hdr
    projects.keys.sort.each do |repo|
      csv << [repo, projects[repo]]
    end
  end

  # Project --> URL mapping
  urls = {}
  CSV.foreach(furls, headers: true) do |row|
    h = row.to_h
    proj = h['project'].strip
    url = h['url'].strip
    if urls.key?(proj) && urls[proj] != url
      puts "Non unique entry: urls: urls['#{proj}'] = '#{urls[proj]}', new value: #{url}"
      return
    end
    urls[proj] = url
  end

  hdr = ['project', 'url']
  CSV.open(furls, "w", headers: hdr) do |csv|
    csv << hdr
    urls.keys.sort.each do |project|
      csv << [project, urls[project]]
    end
  end

  # Final name --> new name mapping
  defmaps = {}
  CSV.foreach(fdefmaps, headers: true) do |row|
    h = row.to_h
    name = h['name'].strip
    project = h['project'].strip
    if defmaps.key?(name) && defmaps[name] != project
      puts "Non unique entry: defmaps: defmaps['#{name}'] = '#{defmaps[name]}', new value: #{project}"
      return
    end
    defmaps[name] = project
  end

  hdr = ['name', 'project']
  CSV.open(fdefmaps, "w", headers: hdr) do |csv|
    csv << hdr
    defmaps.keys.sort.each do |name|
      csv << [name, defmaps[name]]
    end
  end

  # Missing URLs
  urls_found = true
  projects.values.uniq.each do |project|
    unless urls.key? project
      puts "Project '#{project}' have no URL defined, aborting"
      urls_found = false
    end
  end
  defmaps.values.uniq.each do |project|
    unless urls.key? project
      puts "Defmap Project '#{project}' have no URL defined, aborting"
      urls_found = false
    end
  end
  return unless urls_found

  # Analysis:
  # Get repo name from CSV row
  # If repo found in projects set mode to "project" and groupping
  # If project not found and "org" is present set mode to "org" and groupping
  # If mode not determined yet set it to repo
  # Now check if final project key (project, org or repo) is in additional mapping
  # Additional mapping is used to:
  # create better name for data groupped by org (when default is enough) like org = "aspnet" --> ASP.net
  # group multiple orgs and orgs with repos into single project
  orgs = {}
  project_counts = {}
  CSV.foreach(fin, headers: true) do |row|
    h = row.to_h
    repo = h['repo']
    k = h['project'] = projects[repo]
    mode = nil
    if k
      project_counts[k] = [0, []] unless project_counts.key?(k)
      project_counts[k][0] += 1
      project_counts[k][1] << repo
      mode = 'project'
    end
    k = h['org'] unless k
    mode = 'org' if k &&!mode
    k = h['repo'] unless k
    next unless k
    mode = 'repo' unless mode
    if defmaps.key? k
      k = defmaps[k]
      mode = 'defmap'
    end
    h['project'] = k
    h['mode'] = mode
    orgs[k] = { items: [] } unless orgs.key? k
    h.each do |p, v|
      vi = v.to_i
      vis = vi.to_s
      h[p] = vi if vis == v
    end
    orgs[k][:items] << h
  end

  orgs.each do |name, org|
    org[:sum] = {}
    org[:items].each do |repo|
        repo.each do |k, v|
          if v.is_a?(String)
            if repo['org'] && k == 'repo' && v.include?('/')
              v = v.split('/')[1]
            end
            if org[:sum].key? k
              org[:sum][k] = '' if org[:sum][k].nil?
              org[:sum][k] += '+' + v
            else
              org[:sum][k] = v 
            end
          elsif v.is_a?(Integer)
            org[:sum][k] = 0 unless org[:sum].key? k
            org[:sum][k] += v
          else
            org[:sum][k] = nil
          end
        end
    end
    new_org = org[:sum]['org']
    org[:sum]['org'] = new_org.split('+').uniq.join('+') if new_org
    new_prj = org[:sum]['project']
    org[:sum]['project'] = new_prj.split('+').uniq.join('+') if new_prj
    new_mode = org[:sum]['mode']
    org[:sum]['mode'] = new_mode.split('+').uniq.join('+') if new_mode
  end

  orgs_arr = []
  orgs.each do |name, org|
    orgs_arr << [name, org[:sum]['activity'], org]
  end

  res = orgs_arr.sort_by { |item| -item[1] }

  no_url = false
  miss = []
  res.each_with_index do |item, index|
    sum = item[2][:sum]
    project = sum['project']
    if !urls.key?(project)
      s = "Project ##{index} (#{sum['mode']}, #{sum['activity']}) #{project} (#{sum['org']}) (#{sum['repo']}) have no URL defined"
      if index <= 50
        puts s
        no_url = true
      end
      miss << s
      sum['url'] = ''
    else
      sum['url'] = urls[project]
    end
  end
  binding.pry if no_url

  puts 'res[0..30].map { |it| it[0] }'
  puts "Defined projects: "
  prjs = []
  project_counts.keys.sort.each do |k|
    prjs << "#{k}: #{project_counts[k][0]}"
  end
  prjs = prjs.join(', ')
  puts prjs

  puts "Top:"
  tops = res[0..60].map.with_index { |it, idx| "#{idx}) #{it[0]} (#{it[2][:sum]['mode']} #{it[2][:sum]['url']}): #{it[1]}, #{it[2][:sum]['authors']} (#{it[2][:sum]['org']}) (#{it[2][:sum]['repo']})" }
  all = res.map.with_index { |it, idx| "#{idx}) #{it[0]} (#{it[2][:sum]['mode']} #{it[2][:sum]['url']}): #{it[1]}, #{it[2][:sum]['authors']} (#{it[2][:sum]['org']}) (#{it[2][:sum]['repo']})" }
  puts tops
  puts "`all` to see all data, `miss` to see missing project's urls"

  binding.pry

  ks = res[0][2][:sum].keys - ['mode']
  CSV.open(fout, "w", headers: ks) do |csv|
    csv << ks
    res.each do |row|
      csv_row = []
      ks.each do |key|
        csv_row << row[2][:sum][key]
      end
      csv << csv_row
    end
  end
end

if ARGV.size < 5
  puts "Missing arguments: input_data.csv output_projects.csv hints.csv urls.csv defmaps.csv"
  exit(1)
end

analysis(ARGV[0], ARGV[1], ARGV[2], ARGV[3], ARGV[4])

