#!/bin/bash
# bq help query | less
# bq query --destination_table=xxx
cat BigQuery/cncf_small.sql | bq --format=csv --headless query --use_legacy_sql=true -n 1000000 --use_cache > BigQuery/cncf_small.csv
