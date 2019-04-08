#!/bin/bash
if [ -z "$1" ]
then
  echo "$0: you need to provide date-from in YYYY-MM-DD format"
  exit 1
fi
if [ -z "$2" ]
then
  echo "$0: you need to provide date-to in YYYY-MM-DD format"
  exit 2
fi
function finish {
    rm -f /tmp/velocity_bigquery.sql
}
trap finish EXIT

cp BigQuery/velocity_cncf.sql /tmp/velocity_bigquery.sql || exit 3
FROM="{{dtfrom}}" TO="$1" MODE=ss replacer /tmp/velocity_bigquery.sql || exit 4
FROM="{{dtto}}" TO="$2" MODE=ss replacer /tmp/velocity_bigquery.sql || exit 5
ofn="data/data_cncf_projects_${1//-/}_${2//-/}.csv"
cat /tmp/velocity_bigquery.sql | bq --format=csv --headless query --use_legacy_sql=true -n 1000000 --use_cache > "$ofn"
ed "$ofn" <<<$'1d\nwq\n'
echo "$ofn written"
