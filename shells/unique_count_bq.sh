#!/bin/bash
if [ -z "$1" ]
then
  echo "$0: you need to provide 1st arg 'what': sha, author.name, author.email"
  exit 1
fi
if [ -z "$2" ]
then
  echo "$0: you need to provide 2nd arg 'where': 'repo.name = 'torvalds/linux'"
  exit 2
fi
if [ -z "$3" ]
then
  echo "$0: you need to provide 3rd arg 'when': 'year.2018'"
  exit 3
fi
function finish {
    rm -f /tmp/unique_count.sql
}
trap finish EXIT

cp sql/unique_count.sql /tmp/unique_count.sql || exit 4
FROM="{{field}}" TO="$1" MODE=ss replacer /tmp/unique_count.sql || exit 5
FROM="{{cond}}"  TO="$2" MODE=ss replacer /tmp/unique_count.sql || exit 6
FROM="{{table}}" TO="$3" MODE=ss replacer /tmp/unique_count.sql || exit 7
cat /tmp/unique_count.sql | bq --format=csv --headless query --use_legacy_sql=false -n 1000000 --use_cache > unique.csv || exit 8
ed unique.csv <<<$'1d\nwq\n' || exit 9
echo "unique.csv written"
