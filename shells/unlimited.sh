#!/bin/sh
cp data/unlimited_output_201605_201704.csv data/unlimited.csv
ruby add_linux.rb data/unlimited.csv data/data_linux.csv 2016-05-01 2017-05-01
ruby add_external.rb data/unlimited.csv data/data_gitlab.csv 2016-05-01 2017-05-01 gitlab gitlab/GitLab
ruby merger.rb data/unlimited.csv data/data_cncf_projects.csv
ruby merger.rb data/unlimited.csv data/webkit_201605_201704.csv
ruby merger.rb data/unlimited.csv data/data_openstack_201605_201704.csv
ruby merger.rb data/unlimited.csv data/data_apache_201605_201704.csv
ruby analysis.rb data/unlimited.csv projects/unlimited.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges.csv
ruby update_projects.rb projects/unlimited_both.csv data/data_apache_jira.csv -1
ruby update_projects.rb projects/unlimited_both.csv data/data_openstack_bugs.csv 500
