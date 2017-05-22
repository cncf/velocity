#!/bin/sh
ruby add_linux.rb data/unlimited.csv data/data_linux.csv 2016-05-01 2017-05-01
ruby merger.rb data/unlimited.csv data/data_cncf_projects.csv
ruby merger.rb data/unlimited.csv data/webkit_201605_201704.csv
ruby analysis.rb data/unlimited.csv projects/unlimited.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges.csv
