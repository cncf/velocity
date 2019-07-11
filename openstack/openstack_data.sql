select * from (
  select
    o.login as org,
    e.dup_repo_name as repo,
    count(distinct e.id) as activity,
    count(distinct e.id) filter (where e.type in ('IssueCommentEvent', 'CommitCommentEvent', 'PullRequestReviewEvent')) as comments,
    count(distinct e.id) filter (where e.type = 'PullRequestEvent') as prs,
    count(distinct e.id) filter (where e.type = 'PushEvent') as commits,
    count(distinct e.id) filter (where e.type = 'IssuesEvent') as issues,
    count(distinct coalesce(c.encrypted_email, e.dup_actor_login)) as authors_alt2,
    string_agg(distinct coalesce(c.encrypted_email, e.dup_actor_login), ',') as authors_alt1,
    string_agg(distinct coalesce(c.encrypted_email, e.dup_actor_login), ',') as authors,
    count(distinct e.id) filter (where e.type = 'PushEvent') as pushes
  from
    gha_orgs o,
    gha_repos r,
    gha_events e
  left join
    gha_commits c
  on
    e.type = 'PushEvent'
    and e.id = c.event_id
  where
    e.org_id = o.id
    and e.repo_id = r.id
    and r.repo_group = 'OpenStack'
    and e.type in (
      'IssueCommentEvent', 'PullRequestEvent', 'PushEvent', 'IssuesEvent', 'PullRequestReviewEvent', 'CommitCommentEvent'
    )
    -- and (lower(e.dup_actor_login) {{exclude_bots}})
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
  q.authors_alt2 desc,
  q.activity desc
;
