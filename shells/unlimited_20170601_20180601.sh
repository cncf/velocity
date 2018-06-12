#!/bin/sh
echo "Restoring BigQuery output"
cp data/data_20170601_20180601.csv data/unlimited.csv
echo "Adding Linux kernel data"
ruby add_linux.rb data/unlimited.csv data/data_linux.csv 2017-06-01 2018-06-01 || exit 1
echo "Adding GitLab data"
ruby add_external.rb data/unlimited.csv data/data_gitlab.csv 2017-06-01 2018-06-01 gitlab gitlab/GitLab || exit 1
echo "Adding/Updating Cloud Foundry Projects"
# This uses "force" mode to update Cloud Foundry values to lower ones (this is because we have special query output for CF projects which skips more bots, so lower values are expected)
ruby merger.rb data/unlimited.csv data/cf_20170601_20180601.csv force || exit 1
# Don't forget to add exception to map/ranges.csv when adding projects pulled with different BigQuery (specially with 0s for issues, PRs etc)
echo "Adding/Updating CNCF Projects"
ruby merger.rb data/unlimited.csv data/cncf_20170601_20180601.csv || exit 1
echo "Adding/Updating OpenStack case"
ruby merger.rb data/unlimited.csv openstack/data_openstack_2017-06-01_2018-06-01.csv || exit 1
echo "Adding/Updating Apache case"
ruby merger.rb data/unlimited.csv data/apache_20170601_20180601.csv || exit 1
echo "Adding/Updating Chromium case"
ruby merger.rb data/unlimited.csv data/chromium_20170601_20180601.csv || exit 1
echo "Adding/Updating openSUSE case"
ruby merger.rb data/unlimited.csv data/opensuse_20170601_20180601.csv || exit 1
echo "Adding/Updating AutomotiveGradeLinux (AGL) case"
ruby merger.rb data/unlimited.csv data/data_agl_20170601_20180601.csv || exit 1
echo "Adding/Updating LibreOffice case"
ruby merger.rb data/unlimited.csv data/libreoffice_20170601_20180601.csv || exit 1
echo "Adding/Updating FreeBSD Projects"
ruby merger.rb data/unlimited.csv data/freebsd_20170601_20180601.csv || exit 1
echo "Analysis"
ruby analysis.rb data/unlimited.csv projects/unlimited_both.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv || exit 1
echo "Updating OpenStack projects using their bug tracking data"
ruby update_projects.rb projects/unlimited_both.csv data/data_openstack_bugs_20170601_20180601.csv -1 || exit 1
echo "Updating Apache Projects using Jira data"
ruby update_projects.rb projects/unlimited_both.csv data/data_apache_jira_20170601_20180601.csv -1 || exit 1
echo "Updating Chromium project using their bug tracking data"
ruby update_projects.rb projects/unlimited_both.csv data/data_chromium_bugtracker_20170601_20180601.csv -1 || exit 1
echo "Updating LibreOffice project using their git repo"
ruby update_projects.rb projects/unlimited_both.csv data/data_libreoffice_git_20170601_20180601.csv -1 || exit 1
echo "Updating FreeBSD project using their repos SVN data"
ruby update_projects.rb projects/unlimited_both.csv data/data_freebsd_svn_20170601_20180601.csv -1 || exit 1
echo "Generating Projects Ranks statistics"
./shells/report_cncf_project_ranks.sh
./shells/report_other_project_ranks.sh
./report_top_projects.sh
echo "Truncating results to Top 500"
cat ./projects/unlimited_both.csv | head -n 501 > tmp && mv tmp ./projects/unlimited.csv
echo "All done"
