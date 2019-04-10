#!/bin/bash
if [ -z "$1" ]
then
  echo "$0: you need to provide 1st argument datasource table for example 'year.2018'"
  exit 1
fi
if [ -z "$2" ]
then
  echo "$0: you need to provide 2nd argument SHA"
  exit 2
fi
function finish {
    rm -f /tmp/linux_bigquery.sql
}
trap finish EXIT

cp sql/linux_check_sha.sql /tmp/linux_bigquery.sql || exit 3
FROM="{{table}}" TO="$1" MODE=ss replacer /tmp/linux_bigquery.sql || exit 4
FROM="{{sha}}" TO="$2" MODE=ss replacer /tmp/linux_bigquery.sql || exit 5
cat /tmp/linux_bigquery.sql | bq --format=csv --headless query --use_legacy_sql=false -n 1000000 --use_cache || exit 6
