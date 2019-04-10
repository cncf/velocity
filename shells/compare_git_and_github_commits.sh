#!/bin/bash
# TODO: the differences are mostly because many sub-commits are created with their actuall commit date which can be outside the same range for git reporting merge commits
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
repos=`db.sh psql "${1}" -tAc "select distinct name from gha_repos"`
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
  git log --pretty=format:"%H" --since="${2}" --until="${3}" >> "${log}" 2>/dev/null
  if [ ! "$?" = "0" ]
  then
    echo "problems getting $repo git log"
  else
    echo "" >> "${log}"
  fi
done
sed -i '/^$/d' "${log}"
ls -l "${log}"
commitsG=`cat "${log}" | sort | uniq | wc -l`
echo "git: ${1}: ${2} - ${3}: ${commitsG} commits"
commitsD=`db.sh psql "${1}" -tAc "select count(distinct sha) from gha_commits where dup_created_at > '${2}' and dup_created_at <= '${3}'"`
echo "devstats: ${1}: ${2} - ${3}: ${commitsD} commits"
if [ "$commitsG" = "$commitsD" ]
then
  echo "Commits counts match"
  exit 0
fi
cd "${cwd}"
cat "${log}" | sort | uniq > out && mv out "${log}"
commits=`db.sh psql "${1}" -tAc "select distinct sha from gha_commits where dup_created_at > '${2}' and dup_created_at <= '${3}' order by sha"`
echo "$commits" > devstats.log
./compare_logs.rb git.log devstats.log
