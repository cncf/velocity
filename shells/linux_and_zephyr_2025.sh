#!/bin/bash
# SKIP_BQ=1 SKIP_ENRICH=1 SKIP_LKML=1 SKIP_ADD=1 SKIP_ANALYSIS=1 ./shells/linux_and_zephyr_2025.sh
# SKIP_BQ=1 SKIP_LKML=1 ./shells/linux_and_zephyr_2025.sh (for quick regenerate when you already have BigQuery and LKML data that won't change anymore)
if [ -z "${SKIP_BQ}" ]
then
  DBG=1 ./run_bq_templated.sh linux_and_zephyr 20250101 20260101 && \
    cp data/data_linux_and_zephyr_projects_20250101_20260101.csv data/data_linux_and_zephyr_projects_20250101_20260101.raw.csv
else
  cp data/data_linux_and_zephyr_projects_20250101_20260101.raw.csv data/data_linux_and_zephyr_projects_20250101_20260101.csv
fi

if [ -z "${SKIP_ENRICH}" ]
then
  ./tools/enrich_authors/enrich_authors -in data/data_linux_and_zephyr_projects_20250101_20260101.csv -out data/data_linux_and_zephyr_projects_20250101_20260101.enriched.csv -from 2025-01-01 -to 2026-01-01 -forks lf_forks.json -debug && \
    cp data/data_linux_and_zephyr_projects_20250101_20260101.csv data/data_linux_and_zephyr_projects_20250101_20260101.raw.csv && \
    cp data/data_linux_and_zephyr_projects_20250101_20260101.enriched.csv data/data_linux_and_zephyr_projects_20250101_20260101.csv
fi

if [ -z "${SKIP_LKML}" ]
then
  ./lkml_analysis.rb 2025-01-01 2026-01-01 && \
    echo 'Copy LKML data into clipboard and press enter to edit linux data file' && \
    read && \
    vim data/data_linux.csv
fi

if [ -z "${SKIP_ADD}" ]
then
  OVERWRITE=1 SKIP_COMMITS=1 ruby add_linux.rb data/data_linux_and_zephyr_projects_20250101_20260101.csv data/data_linux.csv 2025-01-01 2026-01-01
fi

if [ -z "${SKIP_ANALYSIS}" ]
then
  # export RUBYOPT='-EASCII-8BIT:ASCII-8BIT'
  FORKS_FILE=lf_forks.json ruby analysis.rb data/data_linux_and_zephyr_projects_20250101_20260101.csv projects/projects_linux_and_zephyr_20250101_20260101.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv
fi
