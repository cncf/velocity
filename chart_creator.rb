require 'csv'
require 'pry'

content_top = "<!-- For more on the api used here, see https://developers.google.com/chart/interactive/docs/gallery/bubblechart -->
<html>
  <head>
    <script type='text/javascript' src='https://www.gstatic.com/charts/loader.js'></script>
    <script type='text/javascript'>
      google.charts.load('current', {'packages':['corechart']});
      google.charts.setOnLoadCallback(drawSeriesChart);
    function drawSeriesChart() {
      var data = google.visualization.arrayToDataTable([
        ['ID', 'Commits', 'PRs + Issues', 'Label','Authors'],"

data_row_count = 0;
(!ARGV[3].nil? && ARGV[3].to_i > 0) ? bubble_limit = ARGV[3].to_i : bubble_limit = 999
v_max = h_max = 100
content_data = ""
CSV.foreach(ARGV[0], headers: true) do |row|
  data_row_count += 1
  break if data_row_count > bubble_limit
  bubble_hash = row.to_h
  project_id = bubble_hash['project'].gsub(/'/,'’')
  project_url = bubble_hash['url']
  num_commits = bubble_hash['commits'].to_i
  num_pr_iss = bubble_hash['prs'].to_i + bubble_hash['issues'].to_i
  project_lbl = project_id + ' (' + project_url + ')'
  num_authors =  '%.2f' % Math.sqrt(bubble_hash['authors'].to_i)

  content_data += "        ['#{project_id}',#{num_commits},#{num_pr_iss},'#{project_lbl}',#{num_authors}],\n"

  v_max = num_pr_iss if num_pr_iss > v_max
  h_max = num_commits if num_commits > h_max
end
v_max *= 1.5 
h_max *= 2

content_bottom = "      ]);
      var options = {
        title: '#{ARGV[2]}',
        hAxis: {title: 'Commits', logScale: true, minValue: 50, maxValue: #{h_max.to_i}, minorGridlines:{count: 5}},
        vAxis: {title: 'PRs + Issues', logScale: true, minValue: 50, maxValue: #{v_max.to_i}, minorGridlines:{count: 5}},
        bubble: {textStyle: {fontSize: 12}},
        sizeAxis: {minSize: 12, maxSize: 40},
      };
      var chart = new google.visualization.BubbleChart(document.getElementById('series_chart_div'));
      chart.draw(data, options);
    }
    </script>
  </head>
  <body>
    <div id='series_chart_div' style='width: 100%; height: 100%;'></div>
  </body>
</html>"

# File.open('out.txt', 'w') {|f| f.write('write your stuff here) }
html_file = File.new(ARGV[1], 'w')
html_file.puts(content_top)
html_file.puts(content_data)
html_file.puts(content_bottom)
html_file.close
