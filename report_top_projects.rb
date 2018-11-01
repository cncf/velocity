require 'csv'
require 'pry'
require 'to_regexp'
require './comment'

def report_top_projects(fin, limit)
  # org,repo,activity,comments,prs,commits,issues,authors,project,url
  projs = {}
  CSV.foreach(fin, headers: true) do |row|
    next if is_comment row
    h = row.to_h
    proj = h['project']
    if projs.key? proj
      puts "Project #{proj} already present in projects file"
      return
    end
    projs[proj] = h
  end

  res = []
  metrics = %w(activity comments prs commits issues authors)
  metrics.each_with_index do |metric, index|
    res << []
    projs.each do |name, data|
      res[index] << [name, data[metric].to_i]
    end
  end

  limit = limit - 1
  metrics.each_with_index do |metric, index|
    ary = res[index].sort_by { |r| -r[1] }
    fn = "reports/top_projects_by_#{metric}.txt"
    File.open(fn, 'w') do |rep|
      rep.write("Top projects by #{metric}:\n")
      ary.each_with_index do |row, n|
        if projs[row[0]]['url'].length > 0
          rep.write("#{n+1}) #{row[0]} (#{projs[row[0]]['url']}) #{metric}: #{row[1]}\n")
        else
          rep.write("#{n+1}) #{row[0]} #{metric}: #{row[1]}\n")
        end
        break if n >= limit
      end
    end
  end
end

if ARGV.size < 2
  puts "Missing arguments: projects/unlimited_both.csv N"
  exit(1)
end

report_top_projects(ARGV[0], ARGV[1].to_i)
