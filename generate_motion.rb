require 'csv'
require 'pry'

# Generate merged motion data for files listed in "flist" file (an their motion labels)
# Output to "fout"
def generate(flist, fout)
  files = []
  CSV.foreach(flist, headers: true) do |row|
    h = row.to_h
    name = h['name'].strip
    label = h['label'].strip
    files << [name, label]
  end

  projects = {}
  labels = {}
  files.each do |file_data|
    file, label = file_data
    CSV.foreach(file, headers: true) do |row|
      h = row.to_h
      h.each do |p, v|
        vi = v.to_i
        vis = vi.to_s
        h[p] = vi if vis == v
      end
      project = h['project']
      h['label'] = label
      projects[project] = {} unless projects.key? project
      projects[project][label] = h
      labels[label] = true
    end
  end
  labels = labels.keys

  projects.each do |project, items|
    sum = {}
    labels.each do |label|
      proj = items[label]
      next unless proj
      proj.each do |k, v|
        next if ['org', 'repo'].include? k
        if ['activity', 'comments', 'prs', 'commits', 'issues'].include? k
          sum[k] = 0 unless sum.key? k
          sum[k] += v
        elsif ['project', 'url'].include? k
          sum[k] = v
        elsif k == 'authors'
          sum[k] = v unless sum.key? k
          sum[k] = [sum[k], v].max
        elsif k == 'label'
          sum[k] = [] unless sum.key? k
          sum[k] << v
        else
          puts "Invalid key #{k}"
          p proj
        end
      end
    end
    items[:sum] = sum
  end

  projs_arr = []
  projects.each do |project, items|
    projs_arr << [project, items[:sum]['activity'], items]
  end
  projs_arr = projs_arr.sort_by { |item| -item[1] }

  top_projs = []
  projs_arr.each_with_index do |item, index|
    lbls = item[2][:sum]['label']
    if lbls.size == labels.size
      top_projs << item
    end
  end

  ks = %w(project url label activity comments prs commits issues authors)
  CSV.open(fout, "w", headers: ks) do |csv|
    csv << ks
    top_projs.each do |item|
      proj = item[0]
      authors = 0
      labels.each do |label|
        row = item[2][label]
        authors = [authors, row['authors']].max
        csv_row = [
          proj,
          row['url'],
          label,
          row['activity'],
          row['comments'],
          row['prs'],
          row['commits'],
          row['issues'],
          authors
        ]
        csv << csv_row
      end
    end
  end
end

if ARGV.size < 2
  puts "Missing arguments: files.csv output_motion.csv"
  exit(1)
end

generate(ARGV[0], ARGV[1])

