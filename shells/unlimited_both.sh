#!/bin/sh
echo "Restoring BigQuery output"
cp data/unlimited_output_201605_201704.csv data/unlimited.csv
echo "Adding Linux kernel data"
ruby add_linux.rb data/unlimited.csv data/data_linux.csv 2016-05-01 2017-05-01
echo "Adding GitLab data"
ruby add_external.rb data/unlimited.csv data/data_gitlab.csv 2016-05-01 2017-05-01 gitlab gitlab/GitLab
echo "Adding/Updating CNCF Projects"
ruby merger.rb data/unlimited.csv data/data_cncf_projects.csv
echo "Adding/Updating WebKit case"
ruby merger.rb data/unlimited.csv data/webkit_201605_201704.csv
echo "Adding/Updating OpenStack case"
ruby merger.rb data/unlimited.csv data/data_openstack_201605_201704.csv
echo "Adding/Updating Apache case"
ruby merger.rb data/unlimited.csv data/data_apache_201605_201704.csv
echo "Analysis"
ruby analysis.rb data/unlimited.csv projects/unlimited_both.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv
echo "Updating Apache Projects using Jira data"
ruby update_projects.rb projects/unlimited_both.csv data/data_apache_jira.csv -1
echo "Updating OpenStack projects using their bug tracking data"
ruby update_projects.rb projects/unlimited_both.csv data/data_openstack_bugs.csv -1
echo "Truncating results to Top 500"
cat ./projects/unlimited_both.csv | head -n 501 > tmp && mv tmp ./projects/unlimited_both.csv
echo "All done"
