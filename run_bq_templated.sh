#!/bin/bash
if [ -z "$1" ]
then
  echo "$0: you need to provide 1st arument analysis type, supported are: cncf, lf, top30, cf, apache, chromium, opensuse, libreoffice, freebsd"
  exit 1
fi
if [ -z "$2" ]
then
  echo "$0: you need to provide 2nd argument date-from in YYYYMMDD format"
  exit 2
fi
if [ -z "$3" ]
then
  echo "$0: you need to provide 3rd date-to in YYYYMMDD format"
  exit 3
fi
if [ -z "${DBG}" ]
then
  function finish {
    rm -f /tmp/velocity_bigquery.sql
  }
  trap finish EXIT
fi

cp "BigQuery/velocity_standard_query.sql" /tmp/velocity_bigquery.sql || exit 4
cond=$(cat BigQuery/velocity_condition_${1}.sql)
dtfrom="${2/#20/}"
dtto="${3/#20/}"
FROM="{{dtfrom}}" TO="${dtfrom}" MODE=ss replacer /tmp/velocity_bigquery.sql || exit 5
FROM="{{dtto}}" TO="${dtto}" MODE=ss replacer /tmp/velocity_bigquery.sql || exit 6
FROM="{{cond}}" TO="${cond}" MODE=ss replacer /tmp/velocity_bigquery.sql || exit 7
ofn="data/data_${1}_projects_${2//-/}_${3//-/}.csv"
echo "$ofn"
if [ ! -z "${DBG}" ]
then
  function finish {
    cat "$ofn"
    cat /tmp/velocity_bigquery.sql
  }
  trap finish EXIT
fi
s=$(date +%s%N)
cat /tmp/velocity_bigquery.sql | bq --format=csv --headless query --use_legacy_sql=false -n 1000000 --use_cache > "$ofn" || exit 8
e=$(date +%s%N)
t=$((e - s))
t=$((t / 1000000))
ts=$((t / 1000))
tm=$((ts / 60))
echo "$ofn written in $t ms ($ts s, $tm min)."
