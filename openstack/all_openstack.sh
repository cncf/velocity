#!/bin/bash
if ( [ -z "$1" ] || [ -z "$2" ] )
then
  echo "$0: you need to provide dtfrom and dtto arguments"
  exit 1
fi
exclude="`cat ~/dev/go/src/github.com/cncf/devstats/util_sql/exclude_bots.sql`"
authors=`sudo -u postgres psql contrib -tAc "select count(distinct dup_author_login) from gha_commits where dup_created_at >= '$1' and dup_created_at < '$2'"`
commits=`sudo -u postgres psql contrib -tAc "select count(distinct sha) from gha_commits where dup_created_at >= '$1' and dup_created_at < '$2' and (lower(dup_actor_login) $exclude)"`
issues=`sudo -u postgres psql contrib -tAc "select count(distinct id) from gha_issues where is_pull_request = false and dup_created_at >= '$1' and dup_created_at < '$2'"`
prs=`sudo -u postgres psql contrib -tAc "select count(distinct id) from gha_pull_requests where dup_created_at >= '$1' and dup_created_at < '$2'"`
comments=`sudo -u postgres psql contrib -tAc "select count(distinct id) from gha_comments where dup_created_at >= '$1' and dup_created_at < '$2' and (lower(dup_actor_login) $exclude)"`
pushes=`sudo -u postgres psql contrib -tAc "select count(distinct id) from gha_events where type = 'PushEvent' and created_at >= '$1' and created_at < '$2' and (lower(dup_actor_login) $exclude)"`
activity=`sudo -u postgres psql contrib -tAc "select count(distinct id) from gha_events where created_at >= '$1' and created_at < '$2' and (lower(dup_actor_login) $exclude)"`
#org,repo,activity,comments,prs,commits,issues,authors,pushes,project,url
fn="../data/data_openstack_all_$1_$2.csv"
echo "project,key,value" > "$fn"
echo "OpenStack,authors,$authors" >> "$fn"
echo "OpenStack,commits,$commits" >> "$fn"
echo "OpenStack,issues,$issues" >> "$fn"
echo "OpenStack,prs,$prs" >> "$fn"
echo "OpenStack,comments,$comments" >> "$fn"
echo "OpenStack,pushes,$pushes" >> "$fn"
echo "OpenStack,activity,$activity" >> "$fn"
cat "$fn"
