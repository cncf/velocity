require 'csv'
require 'pry'

def make_hints(fin, fout)
  projects = {}
  [fout, fin].each do |file|
    puts "Processing #{file}"
    begin
      CSV.foreach(file, headers: true) do |row|
        h = row.to_h
        proj = h['project']
        if proj
          proj.strip!
          repo = h['repo'].strip
          if projects.key?(repo) && projects[repo] != proj
            puts "Mapping '#{repo}' -> '#{projects[repo]}' already defined and found new mapping '#{proj}'" 
            next
          end
          projects[repo] = proj
        end
      end
    rescue Errno::ENOENT
    end
  end
  hdr = ['repo', 'project']
  CSV.open(fout, "w", headers: hdr) do |csv|
    csv << hdr
    projects.keys.sort.each do |key|
      csv << [key, projects[key]]
    end
  end
end

if ARGV.size < 2
  puts "Missing arguments: input_file.csv output_hints.csv"
  exit(1)
end

make_hints(ARGV[0], ARGV[1])
