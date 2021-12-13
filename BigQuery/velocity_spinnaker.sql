SELECT
  org,
  repo,
  sum(activity) AS activity,
  sum(comments) AS comments,
  sum(prs) AS prs,
  EXACT_COUNT_DISTINCT(sha) as commits,
  sum(issues) AS issues,
  EXACT_COUNT_DISTINCT(author_email) AS authors_alt2,
  GROUP_CONCAT(STRING(author_name)) AS authors_alt1,
  GROUP_CONCAT(STRING(author_email)) AS authors,
  sum(pushes) AS pushes
FROM (
SELECT
  org.login AS org,
  repo.name AS repo,
  count(*) AS activity,
  SUM(IF(type in ('IssueCommentEvent', 'PullRequestReviewCommentEvent', 'CommitCommentEvent'), 1, 0)) as comments,
  SUM(IF(type = 'PullRequestEvent', 1, 0)) AS prs,
  SUM(IF(type = 'PushEvent', 1, 0)) AS pushes,
  SUM(IF(type = 'IssuesEvent', 1, 0)) AS issues,
  IFNULL(REPLACE(JSON_EXTRACT(payload, '$.commits[0].author.email'), '"', ''), '(null)') AS author_email,
  IFNULL(REPLACE(JSON_EXTRACT(payload, '$.commits[0].author.name'), '"', ''), '(null)') AS author_name,
  JSON_EXTRACT(payload, '$.commits[0].sha') as sha
FROM 
  (SELECT * from
    TABLE_DATE_RANGE([githubarchive:day.],TIMESTAMP('{{dtfrom}}'),TIMESTAMP('{{dtto}}'))
  )
WHERE
  (
    org.login IN ('spinnaker')
  )
  and type in (
    'IssueCommentEvent', 'PullRequestEvent', 'PushEvent', 'IssuesEvent',
    'PullRequestReviewCommentEvent', 'CommitCommentEvent'
  )
GROUP BY org, repo, author_email, author_name, sha
)
GROUP BY org, repo
HAVING 
  authors_alt2 > 5
  AND comments > 50
  AND prs > 10
  AND commits > 10
  AND issues > 10
ORDER BY activity DESC
;
