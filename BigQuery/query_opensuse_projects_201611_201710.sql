select
  org,
  repo,
  sum(activity) as activity,
  sum(comments) as comments,
  sum(prs) as prs,
  sum(commits) as commits,
  sum(issues) as issues,
  EXACT_COUNT_DISTINCT(author_email) as authors_alt2,
  GROUP_CONCAT(STRING(author_name)) AS authors_alt1,
  GROUP_CONCAT(STRING(author_email)) AS authors
from (
select
  org.login as org,
  repo.name as repo,
  count(*) as activity,
  SUM(IF(type = 'IssueCommentEvent', 1, 0)) as comments,
  SUM(IF(type = 'PullRequestEvent', 1, 0)) as prs,
  SUM(IF(type = 'PushEvent', 1, 0)) as commits,
  SUM(IF(type = 'IssuesEvent', 1, 0)) as issues,
  IFNULL(REPLACE(JSON_EXTRACT(payload, '$.commits[0].author.email'), '"', ''), '(null)') as author_email,
  IFNULL(REPLACE(JSON_EXTRACT(payload, '$.commits[0].author.name'), '"', ''), '(null)') as author_name
from
  (select * from
    TABLE_DATE_RANGE([githubarchive:day.],TIMESTAMP('2016-11-01'),TIMESTAMP('2017-11-01'))
  )
where
  org.login = 'openSUSE'
  and type in ('IssueCommentEvent', 'PullRequestEvent', 'PushEvent', 'IssuesEvent')
  and actor.login not like '%bot%'
  AND actor.login NOT IN (
    SELECT
      actor.login
    FROM (
      SELECT
        actor.login,
        COUNT(*) c
      FROM
        TABLE_DATE_RANGE([githubarchive:day.],TIMESTAMP('2016-08-01'),TIMESTAMP('2017-11-01'))
      WHERE
        type = 'IssueCommentEvent'
      GROUP BY
        1
      HAVING
        c > 2500
      ORDER BY
      2 DESC
    )
  )
group by org, repo, author_email, author_name
)
group by org, repo
order by
  activity desc
limit 10000
;

