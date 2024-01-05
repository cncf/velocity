#!/bin/bash
if [ -z "$1" ]
then
  echo "$0: you need to provide 1st arument analysis type, supported are: cncf, lf, top30, cf, apache, chromium, opensuse, libreoffice, freebsd"
  exit 1
fi
if [ -z "$2" ]
then
  echo "$0: you need to provide 2nd argument year in YYYY format"
  exit 2
fi
function finish {
  rm -f /tmp/velocity_bigquery.sql
}
trap finish EXIT

cp "BigQuery/velocity_${1}.sql" /tmp/velocity_bigquery.sql || exit 4
FROM="{{year}}" TO="${2}" MODE=ss replacer /tmp/velocity_bigquery.sql || exit 5
ofn="data/data_${1}_${2}.csv"
echo "$ofn"
cat /tmp/velocity_bigquery.sql | bq --format=csv --headless query --use_legacy_sql=true -n 100000 --use_cache > "$ofn" || exit 7
#ed "$ofn" <<<$'1d\nwq\n' || exit 8
echo "$ofn written"
