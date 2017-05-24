require 'csv'
require 'pry'

def update(fmerge, fdata, n)
  # org,repo,activity,comments,prs,commits,issues,authors,project,url
  projects = {}
  sorted = []
  CSV.foreach(fmerge, headers: true) do |row|
    h = row.to_h
    proj = h['project'].strip
    projects[proj] = h
    sorted << proj
  end

  # project,key,value
  updates = {}
  CSV.foreach(fdata, headers: true) do |row|
    h = row.to_h
    proj = h['project'].strip
    key = h['key'].strip
    updates[[proj,key]] = h['value']
  end

  updated = 0
  updates.each do |what, value|
    proj, key = what
    unless projects.key? proj
      puts "Cannot find project #{proj}"
      next
    end
    unless projects[proj].key? key
      puts "Project #{proj} has no key #{key}"
      next
    end
    if projects[proj][key].to_s == value.to_s
      puts "Project #{proj} already have #{key} = #{value}"
      next
    end
    projects[proj][key] = value
    updated += 1
  end
  puts "Updated #{updated} values"

  # Write changes back to file to update
  hdr = projects.values.first.keys
  CSV.open(fmerge, "w", headers: hdr) do |csv|
    csv << hdr
    lines = 0
    sorted.each do |proj|
      lines += 1
      csv << projects[proj]
      break if lines >= n && n > 0
    end
  end
end

if ARGV.size < 3
  puts "Missing arguments: projects_to_merge.csv additional_data.csv n_rows"
  exit(1)
end

update(ARGV[0], ARGV[1], ARGV[2].to_i)
