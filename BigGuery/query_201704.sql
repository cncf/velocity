SELECT
  org.login as org,
  repo.name as repo,
  count(*) as activity,
  SUM(IF(type = 'IssueCommentEvent', 1, 0)) as comments,
  SUM(IF(type = 'PullRequestEvent', 1, 0)) as prs,
  SUM(IF(type = 'PushEvent', 1, 0)) as commits,
  SUM(IF(type = 'IssuesEvent', 1, 0)) as issues,
  EXACT_COUNT_DISTINCT(JSON_EXTRACT(payload, '$.commits[0].author.email')) AS authors
from (
  select * from 
    [githubarchive:month.201704],
  )
WHERE
  type in ('IssueCommentEvent', 'PullRequestEvent', 'PushEvent', 'IssuesEvent')
  AND (type = 'PushEvent' OR (type != 'PushEvent' AND JSON_EXTRACT_SCALAR(payload, '$.action') in ('created', 'opened', 'reopened')))
  AND repo.id not in (
    SELECT INTEGER(JSON_EXTRACT(payload, '$.forkee.id'))
    FROM
      [githubarchive:month.201704],
      [githubarchive:month.201703],
      [githubarchive:month.201702],
      [githubarchive:month.201701],
      [githubarchive:month.201612],
      [githubarchive:month.201611],
      [githubarchive:month.201610],
      [githubarchive:month.201609],
      [githubarchive:month.201608],
      [githubarchive:month.201607],
      [githubarchive:month.201606],
      [githubarchive:month.201605],
      [githubarchive:month.201604],
      [githubarchive:month.201603],
      [githubarchive:month.201602],
      [githubarchive:month.201601],
    WHERE type = 'ForkEvent'
  )
  AND LOWER(actor.login) not like '%bot%'
  AND LOWER(org.login) not in ('necrobotio', 'githubschool', 'freecodecamp')
  AND actor.login != 'tgstation-server'
  AND actor.login NOT IN (
    SELECT
      actor.login
    FROM (
      SELECT
        actor.login,
        COUNT(*) c
      FROM
      [githubarchive:month.201704],
      [githubarchive:month.201703]
      WHERE
        type = 'IssueCommentEvent'
      GROUP BY
        1
      HAVING
        c > 1000
      ORDER BY
      2 DESC
    )
  )
GROUP BY 
  org, repo
HAVING 
  authors > 5
  and comments > 20
  and prs > 20
  and commits > 10
  and issues > 20
ORDER BY 
  activity desc
limit 1000;