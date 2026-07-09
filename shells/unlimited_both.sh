#!/bin/sh
if [ ! -z "GENERATE" ]
then
  # ./run_bq_standard.sh top30_without_committers 20250701 20260101
  # ./run_bq_standard.sh top30_without_committers 20260101 20260701
  # ./run_bq_standard.sh top30_without_committers 20250701 20260101; ./run_bq_standard.sh top30_without_committers 20260101 20260701; OUT=data/data_top30_without_committers_projects_20250701_20260701.csv ./merge_bq.rb data/data_top30_without_committers_projects_20250701_20260101.csv data/data_top30_without_committers_projects_20260101_20260701.csv
  ./run_bq_standard.sh top30_without_committers 20250701 20260701
  ./tools/enrich_authors/enrich_authors -in data/data_top30_without_committers_projects_20250701_20260701.csv -out data/data_top30_without_committers_projects_20250701_20260701.enriched.csv -from 2025-07-01 -to 2026-07-01 -forks all_forks.json -tmp ./tmp -threads 8
  cp data/data_top30_without_committers_projects_20250701_20260701.csv data/data_top30_without_committers_projects_20250701_20260701.raw.csv
  cp data/data_top30_without_committers_projects_20250701_20260701.enriched.csv data/data_top30_without_committers_projects_20250701_20260701.csv
fi
echo "Restoring BigQuery output"
cp data/data_top30_without_committers_projects_20250701_20260701.csv data/unlimited.csv
echo "Adding Linux kernel data"
ruby add_linux.rb data/unlimited.csv data/data_linux.csv 2025-07-01 2026-07-01
echo "Adding/Updating CNCF Projects"
ruby merger.rb data/unlimited.csv data/data_cncf_projects_20250701_20260701.csv
echo "Analysis"
export RUBYOPT='-EASCII-8BIT:ASCII-8BIT'
# was map/ranges_unlimited.csv
FORKS_FILE=all_forks.json ruby analysis.rb data/unlimited.csv projects/unlimited_both.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv
echo "Prioritizing LF projects data"
PROJFMT=1 ruby update_projects.rb projects/unlimited_both.csv ./projects/projects_lf_20250701_20260701.csv -1
echo "Prioritizing CNCF projects data"
PROJFMT=1 ruby update_projects.rb projects/unlimited_both.csv ./projects/projects_cncf_20250701_20260701.csv -1
echo "Generating Projects Ranks statistics"
./shells/report_cncf_project_ranks.sh
./shells/report_other_project_ranks.sh
./report_top_projects.sh
mkdir reports/20250701_20260701/
cp reports/top_projects_by_*.txt reports/20250701_20260701/
cp reports/*_ranks.txt reports/20250701_20260701/
echo "Truncating results to Top 500"
cat ./projects/unlimited_both.csv | head -n 501 > tmp && mv tmp ./projects/unlimited.csv
echo "All done"
