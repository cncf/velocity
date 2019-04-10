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
  repos=`db.sh psql "${1}" -tAc "select distinct name from gha_repos"`
else
  repos="${REPOS}"
fi
cwd=`pwd`
log="${cwd}/git.log"
> "${log}"
for repo in $repos
do
  if [[ ! $repo == *"/"* ]]
  then
    echo "malformed repo $repo, skipping"
    continue
  fi
  cd "${HOME}/devstats_repos/$repo" 2>/dev/null || echo "no $repo repo"
  git log --all --pretty=format:"%H" --since="${2}" --until="${3}" >> "${log}" 2>/dev/null
  if [ ! "$?" = "0" ]
  then
    echo "problems getting $repo git log"
  else
    echo "" >> "${log}"
  fi
done
sed -i '/^$/d' "${log}"
ls -l "${log}"
commits=`cat "${log}" | sort | uniq | wc -l`
echo "${1}: ${2} - ${3}: ${commits} commits"
