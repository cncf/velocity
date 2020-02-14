#!/bin/sh
echo "Restoring BigQuery output"
cp data/data_top30_projects_20190201_20200201.csv data/unlimited.csv
echo "Adding Linux kernel data"
ruby add_linux.rb data/unlimited.csv data/data_linux.csv 2019-02-01 2020-02-01
# Don't forget to add exception to map/ranges.csv when adding projects pulled with different BigQuery (specially with 0s for issues, PRs etc)
echo "Adding/Updating CNCF Projects"
ruby merger.rb data/unlimited.csv data/data_cncf_projects_20190201_20200201.csv
echo "Adding GitLab data"
ruby add_external.rb data/unlimited.csv data/data_gitlab.csv 2019-02-01 2020-02-01 gitlab gitlab/GitLab
echo "Adding/Updating Cloud Foundry Projects"
# This uses "force" mode to update Cloud Foundry values to lower ones (this is because we have special query output for CF projects which skips more bots, so lower values are expected)
ruby merger.rb data/unlimited.csv data/data_cf_projects_20190201_20200201.csv force
echo "Adding/Updating OpenStack case"
ruby merger.rb data/unlimited.csv openstack/data_openstack_2019-02-01_2020-02-01.csv
echo "Adding/Updating Apache case"
ruby merger.rb data/unlimited.csv data/data_apache_projects_20190201_20200201.csv
echo "Adding/Updating Chromium case"
ruby merger.rb data/unlimited.csv data/data_chromium_projects_20190201_20200201.csv
echo "Adding/Updating OpenSUSE case"
ruby merger.rb data/unlimited.csv data/data_opensuse_projects_20190201_20200201.csv
echo "Adding/Updating AGL case"
ruby merger.rb data/unlimited.csv data/data_agl_projects_20190201_20200201.csv
echo "Adding/Updating LibreOffice case"
ruby merger.rb data/unlimited.csv data/data_libreoffice_projects_20190201_20200201.csv
echo "Adding/Updating FreeBSD case"
ruby merger.rb data/unlimited.csv data/data_freebsd_projects_20190201_20200201.csv
echo "Analysis"
# This is for merged OpenStack into a single project
cp map/defmaps.csv map/defmaps_oo.csv
cat map/defmaps_merged_openstack.csv >> map/defmaps_oo.csv
# ruby analysis.rb data/unlimited.csv projects/unlimited_both.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv
ruby analysis.rb data/unlimited.csv projects/unlimited_both.csv map/hints.csv map/urls.csv map/defmaps_oo.csv map/skip_special.csv map/ranges_sane.csv
echo "Updating Apache Projects using Jira data"
ruby update_projects.rb projects/unlimited_both.csv data/data_apache_jira_20190201_20200201.csv -1
echo "Updating OpenStack projects using their bug tracking data"
ruby update_projects.rb projects/unlimited_both.csv data/data_openstack_bugs_20190201_20200201.csv -1
# This is for merged OpenStack into a single project
ruby update_projects.rb projects/unlimited_both.csv data/data_openstack_all_2019-02-01_2020-02-01.csv -1
echo "Updating Chromium project using their bug tracking data"
ruby update_projects.rb projects/unlimited_both.csv data/data_chromium_bugtracker_20190201_20200201.csv -1
echo "Updating LibreOffice project using their git repo"
ruby update_projects.rb projects/unlimited_both.csv data/data_libreoffice_git_20190201_20200201.csv -1
echo "Updating FreeBSD data from SVN logs"
ruby update_projects.rb projects/unlimited_both.csv ./data/data_freebsd_svn_20190201_20200201.csv -1
echo "Prioritizing LF projects data"
PROJFMT=1 ruby update_projects.rb projects/unlimited_both.csv ./projects/projects_lf_20190201_20200201.csv -1
echo "Prioritizing CNCF projects data"
PROJFMT=1 ruby update_projects.rb projects/unlimited_both.csv ./projects/projects_cncf_20190201_20200201.csv -1
echo "Generating Projects Ranks statistics"
./shells/report_cncf_project_ranks.sh
./shells/report_other_project_ranks.sh
./report_top_projects.sh
echo "Truncating results to Top 500"
cat ./projects/unlimited_both.csv | head -n 501 > tmp && mv tmp ./projects/unlimited.csv
echo "All done"
