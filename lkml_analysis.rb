#!/usr/bin/env ruby

require 'date'
require 'pry'

def lkml_analysis(froms, tos)
  begin
    from = DateTime.strptime(froms, '%Y-%m-%d')
    to = DateTime.strptime(tos, '%Y-%m-%d')
  rescue => e
    puts "#{froms} - #{tos}: #{e}"
    return
  end
  dt = from
  all = 0
  new = 0
  loop do
    sdt = dt.strftime("%Y/%-m/%-d")
    url = "https://lkml.org/lkml/#{sdt}"
    cmd = "wget #{url} -O out 1>/dev/null 2>/dev/null"
    `#{cmd} || exit 1`
    contents = `cat out`
    all_day = contents.scan(/<tr class="c[01]">/).length
    new_day = contents.scan(/<td>\[New\]<\/td>/).length
    all += all_day
    new += new_day
    `rm out`
    dt = dt + 1
    break if dt >= to
  end
  puts "All: #{all}, New: #{new}"
end

if ARGV.size < 2
  puts "Missing arguments: datefrom dateto"
  exit(1)
end

lkml_analysis(ARGV[0], ARGV[1])
