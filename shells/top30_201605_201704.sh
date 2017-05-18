#!/bin/sh
ruby merger.rb data/data_top30_201605_201704.csv data/data_cncf_projects.csv
ruby analysis.rb data/data_top30_201605_201704.csv projects/projects_top30_201605_201704.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges.csv
