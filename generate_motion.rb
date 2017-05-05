require 'csv'
require 'pry'

# Generate merged motion data for files listed in "flist" file (an their motion labels)
# Output to "fout_motion" (per label) and cumulative sums "fout_motion_sums"
def generate(flist, fout_motion, fout_motion_sums)
  sort_column = 'authors'

  files = []
  CSV.foreach(flist, headers: true) do |row|
    h = row.to_h
    name = h['name'].strip
    label = h['label'].strip
    files << [name, label]
  end

  # Read data from files and labels list in "flist"
  projects = {}
  labels = {}
  files.each do |file_data|
    file, label = file_data
    CSV.foreach(file, headers: true) do |row|
      h = row.to_h
      h.each do |p, v|
        vi = v.to_i
        vis = vi.to_s
        # Convert string that contian integers to integers
        h[p] = vi if vis == v
      end
      project = h['project']
      h['label'] = label
      projects[project] = {} unless projects.key? project
      projects[project][label] = h
      labels[label] = true
    end
  end

  # Labels should be alpabetical (actually google sheet reuires time data)
  # So I suggest YYYYMM or YYYY-MM etc, MM/YYYY sorted alphabetically will give wrong result
  # 1/2017 < 2/2016
  labels = labels.keys

  # Compute sums
  projects.each do |project, items|
    sum = {}
    cum_labels = []
    labels.each do |label|
      proj = items[label]
      next unless proj
      cum_labels << label
      proj.each do |k, v|
        next if ['org', 'repo'].include? k
        if ['activity', 'comments', 'prs', 'commits', 'issues'].include? k
          sum[k] = 0 unless sum.key? k
          sum[k] += v
        elsif ['project', 'url'].include? k
          sum[k] = v
        elsif k == 'authors'
          # Column authors is not summed but max'ed
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
      # This is nasty
      items[[label]] = [cum_labels.dup, sum.dup]
    end
    items[:sum] = sum
  end

  # Sort by sort_column (sum of data from all data files)
  # It determines top projects
  projs_arr = []
  projects.each do |project, items|
    projs_arr << [project, items[:sum][sort_column], items]
  end
  projs_arr = projs_arr.sort_by { |item| -item[1] }

  # Only put project in output if it have data in all labels
  top_projs = []
  projs_arr.each_with_index do |item, index|
    lbls = item[2][:sum]['label']
    if lbls.size == labels.size
      top_projs << item
    end
  end

  # Motion chart data
  ks = %w(project url label activity comments prs commits issues authors)
  ks += %w(sum_activity sum_comments sum_prs sum_commits sum_issues sum_authors)
  CSV.open(fout_motion, "w", headers: ks) do |csv|
    csv << ks
    top_projs.each do |item|
      proj = item[0]
      sum = item[2][:sum]
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
          authors,
          sum['activity'],
          sum['comments'],
          sum['prs'],
          sum['commits'],
          sum['issues'],
          sum['authors']
        ]
        csv << csv_row
      end
    end
  end

  # Cumulative sums
  CSV.open(fout_motion_sums, "w", headers: ks) do |csv|
    csv << ks
    top_projs.each do |item|
      proj = item[0]
      sum = item[2][:sum]
      authors = 0
      labels.each do |label|
        # sum_labels = item[2][[label]][0]
        # puts "#{proj} #{sum_labels}"
        row = item[2][[label]][1]
        csv_row = [
          proj,
          row['url'],
          label,
          row['activity'],
          row['comments'],
          row['prs'],
          row['commits'],
          row['issues'],
          row['authors'],
          sum['activity'],
          sum['comments'],
          sum['prs'],
          sum['commits'],
          sum['issues'],
          sum['authors']
        ]
        csv << csv_row
      end
    end
  end
end

if ARGV.size < 3
  puts "Missing arguments: files.csv motion.csv motion_sums.csv"
  exit(1)
end

generate(ARGV[0], ARGV[1], ARGV[2])

