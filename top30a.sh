#!/bin/bash
FORKS_FILE=all_forks.json ruby analysis.rb data/unlimited.csv projects/unlimited_both.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv 1>> ./top30a.log 2>> ./top30a.err
