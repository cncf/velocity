select * from (
  select
    o.login as org,
    e.dup_repo_name as repo,
    count(distinct e.id) as activity,
    count(distinct e.id) filter (where e.type = 'IssueCommentEvent') as comments,
    count(distinct e.id) filter (where e.type = 'PullRequestEvent') as prs,
    count(distinct e.id) filter (where e.type = 'PushEvent') as commits,
    count(distinct e.id) filter (where e.type = 'IssuesEvent') as issues,
    string_agg(distinct e.dup_actor_login, ',') as authors_alt2,
    string_agg(distinct e.dup_actor_login, ',') as authors_alt1,
    count(distinct e.dup_actor_login) as authors
  from
    gha_events e,
    gha_orgs o,
    gha_repos r
  where
    e.org_id = o.id
    and e.repo_id = r.id
    and r.repo_group = 'OpenStack'
    and e.type in (
      'IssueCommentEvent', 'PullRequestEvent', 'PushEvent', 'IssuesEvent'
    )
    and e.dup_actor_login != 'openstack-gerrit'
    and e.dup_actor_login not like '%bot%'
    and e.created_at >= '{{from}}'
    and e.created_at < '{{to}}'
    and e.actor_id not in (
      select
        sub.actor_id
      from (
        select
          actor_id,
          count(id) as c
        from 
          gha_events 
      	where
          type = 'IssueCommentEvent'
          and created_at >= '{{from}}'
          and created_at < '{{to}}'
        group by
          actor_id
        ) sub
      where
        sub.c > 2500
    )
  group by
    o.login,
    e.dup_repo_name
) q
order by
  q.authors desc,
  q.activity desc
;
