#!/bin/bash
if [ -z "$1" ]
then
  echo "$0: you need to provide datasource table for example 'year.2018'"
  exit 1
fi
function finish {
    rm -f /tmp/linux_bigquery.sql
}
trap finish EXIT

cp sql/linux_commits_bigquery.sql /tmp/linux_bigquery.sql || exit 2
FROM="{{table}}" TO="$1" MODE=ss replacer /tmp/linux_bigquery.sql || exit 3
ofn="linux_${1}.csv"
cat /tmp/linux_bigquery.sql | bq --format=csv --headless query --use_legacy_sql=false -n 1000000 --use_cache > "$ofn" || exit 4
ed "$ofn" <<<$'1d\nwq\n' || exit 5
echo "$ofn written"
