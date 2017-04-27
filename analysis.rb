require 'csv'
require 'pry'

def analysis(fin, fout, fhint)
  projects = {}
  CSV.foreach(fhint, headers: true) do |row|
    h = row.to_h
    proj = h['project'].strip
    repo = h['repo'].strip
    projects[repo] = proj
  end

  orgs = {}
  project_counts = {}
  CSV.foreach(fin, headers: true) do |row|
    h = row.to_h
    repo = h['repo']
    k = h['project'] = projects[repo]
    if k
      project_counts[k] = [0, []] unless project_counts.key?(k)
      project_counts[k][0] += 1
      project_counts[k][1] << repo
    end
    k = h['org'] unless k
    k = h['repo'] unless k
    next unless k
    h['project'] = k
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
  end

  orgs_arr = []
  orgs.each do |name, org|
    orgs_arr << [name, org[:sum]['activity'], org]
  end

  res = orgs_arr.sort_by { |item| -item[1] }

  puts 'res[0..30].map { |it| it[0] }'
  puts "Defined projects: "
  prjs = []
  project_counts.keys.sort.each do |k|
    prjs << "#{k}: #{project_counts[k][0]}"
  end
  prjs = prjs.join(', ')
  puts prjs

  puts "Top:"
  tops = res[0..60].map.with_index { |it, idx| "#{idx}) #{it[0]}: #{it[1]} (#{it[2][:sum]['org']}) (#{it[2][:sum]['repo']})" }
  puts tops

  binding.pry

  CSV.open(fout, "w", headers: res[0][2][:sum].keys) do |csv|
    csv << res[0][2][:sum].keys
    res.each do |row|
      csv << row[2][:sum].values
    end
  end
end

if ARGV.size < 3
  puts "Missing arguments: input_data.csv output_projects.csv hints.csv"
  exit(1)
end

analysis(ARGV[0], ARGV[1], ARGV[2])

