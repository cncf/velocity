#!/bin/bash
if [ -z "$1" ]
then
  echo "$0: you need to provide 1st arument analysis type, supported are: cncf, lf, top30, cf, apache, chromium, opensuse, libreoffice, freebsd"
  exit 1
fi
if [ -z "$2" ]
then
  echo "$0: you need to provide 2nd argument date-from in YYYY-MM-DD format"
  exit 2
fi
if [ -z "$3" ]
then
  echo "$0: you need to provide 3rd date-to in YYYY-MM-DD format"
  exit 3
fi
function finish {
  rm -f /tmp/velocity_bigquery.sql
}
trap finish EXIT

cp "BigQuery/velocity_${1}.sql" /tmp/velocity_bigquery.sql || exit 4
FROM="{{dtfrom}}" TO="$2" MODE=ss replacer /tmp/velocity_bigquery.sql || exit 5
FROM="{{dtto}}" TO="$3" MODE=ss replacer /tmp/velocity_bigquery.sql || exit 6
ofn="data/data_${1}_projects_${2//-/}_${3//-/}.csv"
echo "$ofn"
cat /tmp/velocity_bigquery.sql | bq --format=csv --headless query --use_legacy_sql=true -n 1000000 --use_cache > "$ofn" || exit 7
#ed "$ofn" <<<$'1d\nwq\n' || exit 8
echo "$ofn written"
