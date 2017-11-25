#!/bin/sh
echo "Restoring BigQuery output"
cp data/unlimited_output_201611_201710.csv data/unlimited.csv
echo "Adding Linux kernel data"
ruby add_linux.rb data/unlimited.csv data/data_linux.csv 2016-11-01 2017-11-01
echo "Adding GitLab data"
ruby add_external.rb data/unlimited.csv data/data_gitlab.csv 2016-11-01 2017-11-01 gitlab gitlab/GitLab
echo "Adding/Updating Cloud Foundry Projects"
# This uses "force" mode to update Cloud Foundry values to lower ones (this is because we have special query output for CF projects which skips more bots, so lower values are expected)
ruby merger.rb data/unlimited.csv data/data_cloudfoundry_201611_201710.csv force
# Don't forget to add exception to map/ranges.csv when adding projects pulled with different BigQuery (specially with 0s for issues, PRs etc)
echo "Adding/Updating CNCF Projects"
ruby merger.rb data/unlimited.csv data/data_cncf_projects_201611_201710.csv
echo "Adding/Updating WebKit case"
ruby merger.rb data/unlimited.csv data/webkit_201611_201710.csv
echo "Adding/Updating OpenStack case"
ruby merger.rb data/unlimited.csv data/data_openstack_201611_201710.csv
echo "Adding/Updating Apache case"
ruby merger.rb data/unlimited.csv data/data_apache_201611_201710.csv
echo "Adding/Updating Chromium case"
ruby merger.rb data/unlimited.csv data/data_chromium_201611_201710.csv
echo "Adding/Updating openSUSE case"
ruby merger.rb data/unlimited.csv data/data_opensuse_201611_201710.csv
echo "Adding/Updating AutomotiveGradeLinux (AGL) case"
ruby merger.rb data/unlimited.csv data/data_agl_201611_201710.csv
echo "Adding/Updating LibreOffice case"
ruby merger.rb data/unlimited.csv data/data_libreoffice_201611_201710.csv
echo "Adding/Updating FreeBSD Projects"
ruby merger.rb data/unlimited.csv data/data_freebsd_201611_201710.csv
echo "Analysis"
ruby analysis.rb data/unlimited.csv projects/unlimited_both.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv
echo "Updating OpenStack projects using their bug tracking data"
ruby update_projects.rb projects/unlimited_both.csv data/data_openstack_bugs_201611_201710.csv -1
echo "Updating Apache Projects using Jira data"
ruby update_projects.rb projects/unlimited_both.csv data/data_apache_jira_201611_201710.csv -1
echo "Updating Chromium project using their bug tracking data"
ruby update_projects.rb projects/unlimited_both.csv data/data_chromium_bugtracker_201611_201710.csv -1
echo "Updating LibreOffice project using their git repo"
ruby update_projects.rb projects/unlimited_both.csv data/data_libreoffice_git_201611_201710.csv -1
echo "Updating FreeBSD project using their repos SVN data"
ruby update_projects.rb projects/unlimited_both.csv data/data_freebsd_svn_201611_201710.csv -1
echo "Generating Projects Ranks statistics"
./shells/report_cncf_project_ranks.sh
./shells/report_other_project_ranks.sh
echo "Truncating results to Top 500"
cat ./projects/unlimited_both.csv | head -n 501 > tmp && mv tmp ./projects/unlimited.csv
echo "All done"
