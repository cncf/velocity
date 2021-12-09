#!/bin/sh
echo "Restoring BigQuery output"
cp data/data_top30_projects_20210701_20220101.csv data/unlimited.csv
echo "Adding Linux kernel data"
ruby add_linux.rb data/unlimited.csv data/data_linux.csv 2021-07-01 2022-01-01
# Don't forget to add exception to map/ranges.csv when adding projects pulled with different BigQuery (specially with 0s for issues, PRs etc)
echo "Adding/Updating CNCF Projects"
ruby merger.rb data/unlimited.csv data/data_cncf_projects_20210701_20220101.csv
echo "Adding/Updating Cloud Foundry Projects"
# This uses "force" mode to update Cloud Foundry values to lower ones (this is because we have special query output for CF projects which skips more bots, so lower values are expected)
ruby merger.rb data/unlimited.csv data/data_cf_projects_20210701_20220101.csv force
echo "Adding/Updating Apache case"
ruby merger.rb data/unlimited.csv data/data_apache_projects_20210701_20220101.csv
echo "Adding/Updating OpenSUSE case"
ruby merger.rb data/unlimited.csv data/data_opensuse_projects_20210701_20220101.csv
echo "Adding/Updating FreeBSD case"
ruby merger.rb data/unlimited.csv data/data_freebsd_projects_20210701_20220101.csv
echo "Analysis"
ruby analysis.rb data/unlimited.csv projects/unlimited_both.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv
echo "Updating Apache Projects using Jira data"
ruby update_projects.rb projects/unlimited_both.csv data/data_apache_jira_20210701_20220101.csv -1
echo "Updating FreeBSD data from SVN logs"
ruby update_projects.rb projects/unlimited_both.csv ./data/data_freebsd_svn_20210701_20220101.csv -1
echo "Prioritizing LF projects data"
PROJFMT=1 ruby update_projects.rb projects/unlimited_both.csv ./projects/projects_lf_20210701_20220101.csv -1
echo "Prioritizing CNCF projects data"
PROJFMT=1 ruby update_projects.rb projects/unlimited_both.csv ./projects/projects_cncf_20210701_20220101.csv -1
echo "Generating Projects Ranks statistics"
./shells/report_cncf_project_ranks.sh
./shells/report_other_project_ranks.sh
./report_top_projects.sh
echo "Truncating results to Top 500"
cat ./projects/unlimited_both.csv | head -n 501 > tmp && mv tmp ./projects/unlimited.csv
echo "All done"
