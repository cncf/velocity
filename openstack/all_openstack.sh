#!/bin/bash
if ( [ -z "$1" ] || [ -z "$2" ] )
then
  echo "$0: you need to provide dtfrom and dtto arguments"
  exit 1
fi
exclude="`cat ~/dev/go/src/github.com/cncf/devstats/util_sql/exclude_bots.sql`"
authors=`sudo -u postgres psql contrib -tAc "select count(distinct c.encrypted_email) from gha_commits c, gha_repos r where r.id = c.dup_repo_id and r.name = c.dup_repo_name and r.repo_group = 'OpenStack' and c.dup_created_at >= '$1' and c.dup_created_at < '$2'"`
commits=`sudo -u postgres psql contrib -tAc "select count(distinct c.sha) from gha_commits c, gha_repos r where r.id = c.dup_repo_id and r.name = c.dup_repo_name and r.repo_group = 'OpenStack' and c.dup_created_at >= '$1' and c.dup_created_at < '$2' and (lower(c.dup_actor_login) $exclude)"`
issues=`sudo -u postgres psql contrib -tAc "select count(distinct i.id) from gha_issues i, gha_repos r where r.id = i.dup_repo_id and r.name = i.dup_repo_name and r.repo_group = 'OpenStack' and i.is_pull_request = false and i.dup_created_at >= '$1' and i.dup_created_at < '$2'"`
prs=`sudo -u postgres psql contrib -tAc "select count(distinct pr.id) from gha_pull_requests pr, gha_repos r where r.id = pr.dup_repo_id and r.name = pr.dup_repo_name and r.repo_group = 'OpenStack' and pr.dup_created_at >= '$1' and pr.dup_created_at < '$2'"`
comments=`sudo -u postgres psql contrib -tAc "select count(distinct c.id) from gha_comments c, gha_repos r where r.id = c.dup_repo_id and r.name = c.dup_repo_name and r.repo_group = 'OpenStack' and c.dup_created_at >= '$1' and c.dup_created_at < '$2' and (lower(c.dup_actor_login) $exclude)"`
pushes=`sudo -u postgres psql contrib -tAc "select count(distinct e.id) from gha_events e, gha_repos r where r.id = e.repo_id and r.name = e.dup_repo_name and r.repo_group = 'OpenStack' and e.type = 'PushEvent' and e.created_at >= '$1' and e.created_at < '$2' and (lower(e.dup_actor_login) $exclude)"`
activity=`sudo -u postgres psql contrib -tAc "select count(distinct e.id) from gha_events e, gha_repos r where r.id = e.repo_id and r.name = e.dup_repo_name and r.repo_group = 'OpenStack' and e.created_at >= '$1' and e.created_at < '$2' and (lower(e.dup_actor_login) $exclude)"`
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
