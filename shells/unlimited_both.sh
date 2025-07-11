#!/bin/sh
if [ ! -z "GENERATE" ]
then
  # ./run_bq_standard.sh top30 20240701 20250101
  # ./run_bq_standard.sh top30 20250101 20250701
  # OUT=data/data_top30_projects_20240701_20250701.csv ./merge_bq.rb data/data_top30_projects_20240701_20250101.csv data/data_top30_projects_20250101_20250701.csv
  ./run_bq_standard.sh top30 20240701 20250701
fi
echo "Restoring BigQuery output"
cp data/data_top30_projects_20240701_20250701.csv data/unlimited.csv
echo "Adding Linux kernel data"
ruby add_linux.rb data/unlimited.csv data/data_linux.csv 2024-07-01 2025-07-01
# Don't forget to add exception to map/ranges.csv when adding projects pulled with different BigQuery (specially with 0s for issues, PRs etc)
echo "Adding/Updating CNCF Projects"
ruby merger.rb data/unlimited.csv data/data_cncf_projects_20240701_20250701.csv
echo "Analysis"
FORKS_FILE=all_forks.json ruby analysis.rb data/unlimited.csv projects/unlimited_both.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv
echo "Prioritizing LF projects data"
PROJFMT=1 ruby update_projects.rb projects/unlimited_both.csv ./projects/projects_lf_20240701_20250701.csv -1
echo "Prioritizing CNCF projects data"
PROJFMT=1 ruby update_projects.rb projects/unlimited_both.csv ./projects/projects_cncf_20240701_20250701.csv -1
echo "Generating Projects Ranks statistics"
./shells/report_cncf_project_ranks.sh
./shells/report_other_project_ranks.sh
./report_top_projects.sh
mkdir reports/20240701_20250701/
cp reports/top_projects_by_*.txt reports/20240701_20250701/
cp reports/*_ranks.txt reports/20240701_20250701/
echo "Truncating results to Top 500"
cat ./projects/unlimited_both.csv | head -n 501 > tmp && mv tmp ./projects/unlimited.csv
echo "All done"
