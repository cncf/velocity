#!/bin/sh
ruby analysis.rb data/data_cncf_projects.csv projects/projects_cncf.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_unlimited.csv
ruby analysis.rb data/data_cncf_projects_201704.csv projects/projects_cncf_201704.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_unlimited.csv
