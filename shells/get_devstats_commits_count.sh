#!/bin/bash
# REPOS=... - manually specify repos
if [ -z "$PG_PASS" ]
then
  echo "$0: you need to set PG_PASS=..."
  exit 1
fi
if [ -z "$1" ]
then
  echo "$0: you need to provide 1st argument proect database name: gha, prometheus, cncf, allprj etc."
  exit 2
fi
if [ -z "$2" ]
then
  echo "$0: you need to provide 2nd argument date-from in YYYY-MM-DD format"
  exit 3
fi
if [ -z "$3" ]
then
  echo "$0: you need to provide 3rd date-to in YYYY-MM-DD format"
  exit 4
fi
if [ -z "$REPOS" ]
then
  commits=`db.sh psql "${1}" -tAc "select count(distinct sha) from gha_commits where dup_created_at > '${2}' and dup_created_at <= '${3}'"`
else
  commits=`db.sh psql "${1}" -tAc "select count(distinct sha) from gha_commits where dup_created_at > '${2}' and dup_created_at <= '${3}' and dup_repo_name in (${REPOS})"`
fi
echo "${1}: ${2} - ${3}: ${commits} commits"
