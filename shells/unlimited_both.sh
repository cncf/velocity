#!/bin/sh
echo "Restoring BigQuery output"
cp data/unlimited_output_20170801_20180801.csv data/unlimited.csv
echo "Adding Linux kernel data"
ruby add_linux.rb data/unlimited.csv data/data_linux.csv 2017-08-01 2018-08-01
echo "Adding GitLab data"
ruby add_external.rb data/unlimited.csv data/data_gitlab.csv 2017-08-01 2018-08-01 gitlab gitlab/GitLab
echo "Adding/Updating Cloud Foundry Projects"
# This uses "force" mode to update Cloud Foundry values to lower ones (this is because we have special query output for CF projects which skips more bots, so lower values are expected)
ruby merger.rb data/unlimited.csv data/data_cloudfoundry_20170801_20180801.csv force
# Don't forget to add exception to map/ranges.csv when adding projects pulled with different BigQuery (specially with 0s for issues, PRs etc)
echo "Adding/Updating CNCF Projects"
ruby merger.rb data/unlimited.csv data/data_cncf_projects.csv
echo "Adding/Updating WebKit case"
ruby merger.rb data/unlimited.csv data/webkit_20170801_20180801.csv
echo "Adding/Updating OpenStack case"
ruby merger.rb data/unlimited.csv openstack/data_openstack_2017-08-01_2018-08-01.csv
echo "Adding/Updating Apache case"
ruby merger.rb data/unlimited.csv data/data_apache_20170801_20180801.csv
echo "Adding/Updating Chromium case"
ruby merger.rb data/unlimited.csv data/data_chrome_chromium_20170801_20180801.csv
echo "Adding/Updating openSUSE case"
ruby merger.rb data/unlimited.csv data/data_opensuse_20170801_20180801.csv
echo "Adding/Updating AGL case"
ruby merger.rb data/unlimited.csv data/data_agl_20170801_20180801.csv
echo "Adding/Updating LibreOffice case"
ruby merger.rb data/unlimited.csv data/data_libreoffice_20170801_20180801.csv
echo "Adding/Updating FreeBSD case"
ruby merger.rb data/unlimited.csv data/data_freebsd_20170801_20180801.csv
echo "Analysis"
ruby analysis.rb data/unlimited.csv projects/unlimited_both.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv
echo "Updating Apache Projects using Jira data"
ruby update_projects.rb projects/unlimited_both.csv data/data_apache_jira_20170801_20180801.csv -1
echo "Updating OpenStack projects using their bug tracking data"
ruby update_projects.rb projects/unlimited_both.csv data/data_openstack_bugs.csv -1
echo "Updating Chromium project using their bug tracking data"
ruby update_projects.rb projects/unlimited_both.csv data/data_chromium_bugtracker.csv -1
echo "Updating LibreOffice project using their git repo"
ruby update_projects.rb projects/unlimited_both.csv data/data_libreoffice_git.csv -1
echo "Updating WebKit project using gitdm and other"
ruby update_projects.rb projects/unlimited_both.csv data/data_webkit_gitdm_and_others.csv -1
echo "Updating FreeBSD data from SVN logs"
ruby update_projects.rb projects/unlimited_both.csv ./data/data_freebsd_svn_20170801_20180801.csv -1
echo "Generating Projects Ranks statistics"
./shells/report_project_ranks.sh
./shells/report_cf_project_ranks.sh
echo "Truncating results to Top 500"
cat ./projects/unlimited_both.csv | head -n 501 > tmp && mv tmp ./projects/unlimited.csv
echo "All done"
