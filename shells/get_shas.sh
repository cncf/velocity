#!/bin/bash
if [ -z "$1" ]
then
  echo "$0: you need to provide datasource table for example 'year.2018'"
  exit 1
fi
if [ -z "$2" ]
then
  echo "$0: you need to provide condition for example 'repo.id in (20580498, 40511817)'"
  exit 2
fi
function finish {
    rm -f /tmp/shas_query.sql
}
trap finish EXIT

cp sql/get_shas.sql /tmp/shas_bigquery.sql || exit 3
FROM="{{table}}" TO="$1" MODE=ss replacer /tmp/shas_bigquery.sql || exit 4
FROM="{{cond}}" TO="$2" MODE=ss replacer /tmp/shas_bigquery.sql || exit 5
cat /tmp/shas_bigquery.sql | bq --format=csv --headless query --use_legacy_sql=false -n 10000000 --use_cache > out.csv || exit 6
ed out.csv <<<$'1d\nwq\n' || exit 7
