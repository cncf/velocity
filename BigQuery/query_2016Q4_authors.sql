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
SELECT
  org.login as org,
  repo.name as repo,
  count(*) as activity,
  SUM(IF(type = 'IssueCommentEvent', 1, 0)) as comments,
  SUM(IF(type = 'PullRequestEvent', 1, 0)) as prs,
  SUM(IF(type = 'PushEvent', 1, 0)) as commits,
  SUM(IF(type = 'IssuesEvent', 1, 0)) as issues,
  IFNULL(REPLACE(JSON_EXTRACT(payload, '$.commits[0].author.email'), '"', ''), '(null)') as author_email,
  IFNULL(REPLACE(JSON_EXTRACT(payload, '$.commits[0].author.name'), '"', ''), '(null)') as author_name
from (
  select * from 
    [githubarchive:month.201612],
    [githubarchive:month.201611],
    [githubarchive:month.201610],
  )
WHERE
  type in ('IssueCommentEvent', 'PullRequestEvent', 'PushEvent', 'IssuesEvent')
  AND (type = 'PushEvent' OR (type != 'PushEvent' AND JSON_EXTRACT_SCALAR(payload, '$.action') in ('created', 'opened', 'reopened')))
  AND repo.id not in (
    SELECT INTEGER(JSON_EXTRACT(payload, '$.forkee.id'))
    FROM
      [githubarchive:year.2016],
      [githubarchive:year.2015],
    WHERE type = 'ForkEvent'
  )
  AND LOWER(repo.name) not like '%school%'
  AND LOWER(repo.name) not like '%trainin%'
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
      [githubarchive:year.2016],
      [githubarchive:year.2015],
      WHERE
        type = 'IssueCommentEvent'
      GROUP BY
        1
      HAVING
        c > 4500
      ORDER BY
      2 DESC
    )
  )
GROUP BY 
  org, repo, author_email, author_name
)
GROUP BY org, repo
HAVING 
  authors_alt2 > 10
  and comments > 50
  and prs > 50
  and commits > 20
  and issues > 50
ORDER BY 
  authors_alt2 desc
limit 5000;

