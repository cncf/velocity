#!/bin/bash
# bq help query | less
# bq query --destination_table=xxx
cat BigQuery/query_20171101_20181101_unlimited.sql | bq --format=csv --headless query --use_legacy_sql=true -n 1000000 --use_cache > data/unlimited_output_20171101_20181101.csv
