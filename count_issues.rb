require 'csv'
require 'pry'
require 'date'
require './comment'

def count_issues(fin, issue_date_column, dfrom, dto)
  return unless dt_from = DateTime.parse(dfrom)
  return unless dt_to = DateTime.parse(dto)
  return unless dt_to > dt_from
  puts "Counting issues in '#{fin}', issue date column is '#{issue_date_column}', range: #{dt_from} - #{dt_to}"

  found = 0
  CSV.foreach(fin, headers: true) do |row|
    next if is_comment row
    h = row.to_h
    issue_date = h[issue_date_column]
    next unless issue_date
    issue_date = DateTime.parse(issue_date)
    found += 1 if issue_date > dt_from && issue_date <= dt_to
  end
  puts "Found #{found} matching issues."
end

if ARGV.size < 3
  puts "Missing arguments: data/data_libreoffice_bugs.csv issue_date_col_name date_from date_to"
  exit(1)
end

count_issues(ARGV[0], ARGV[1], ARGV[2], ARGV[3])
