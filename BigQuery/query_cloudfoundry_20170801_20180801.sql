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
    TABLE_DATE_RANGE([githubarchive:day.],TIMESTAMP('2017-08-01'),TIMESTAMP('2018-07-31'))
  )
WHERE
  type in ('IssueCommentEvent', 'PullRequestEvent', 'PushEvent', 'IssuesEvent')
  AND (type = 'PushEvent' OR (type != 'PushEvent' AND JSON_EXTRACT_SCALAR(payload, '$.action') in ('created', 'opened', 'reopened')))
  AND repo.id not in (
    SELECT INTEGER(JSON_EXTRACT(payload, '$.forkee.id'))
    FROM
    	  TABLE_DATE_RANGE([githubarchive:day.],TIMESTAMP('2017-08-01'),TIMESTAMP('2018-07-31'))
    WHERE type = 'ForkEvent'
 )
  AND org.login in ('cloudfoundry', 'cloudfoundry-attic', 'cloudfoundry-community', 'cloudfoundry-incubator', 'cloudfoundry-samples')
  AND LOWER(actor.login) not like '%bot%'
  AND LOWER(actor.login) not like '%cf-%'
  AND LOWER(actor.login) not in ('pubtools-doc-helper', 'routing-ci', 'runtime-ci', 'cf-buildpacks-eng', 'coveralls', 'garden-gnome', 
  'flintstonecf', 'CI Pool Resource', 'CF Buildpacks Team CI Server', 'CF MEGA BOT', 'git', 'I am Groot CI', 'CI (Automated)',
  'CI (automated)', 'CI Bot', 'Loggregator CI', 'CI', 'CF INFRASTRUCTURE BOT', 'bot', 'CAPI CI', 'cf-loggregator', 'BOSH CI', 'persi-ci',
  'CF Loggregator CI Pipeline', 'CI Submodule AutoUpdate', 'CF-Identity', 'Concourse CI', 'Greenhouse CI', 'cf-infra-bot',
  'Pivotal Concourse Bot')
  AND actor.login NOT IN (
    SELECT
      actor.login
    FROM (
      SELECT
        actor.login,
        COUNT(*) c
      FROM
      TABLE_DATE_RANGE([githubarchive:day.],TIMESTAMP('2017-08-01'),TIMESTAMP('2018-07-31'))
      WHERE
        type = 'IssueCommentEvent'
      GROUP BY
        1
      HAVING
        c > 2000
      ORDER BY
      2 DESC
    )
  )
GROUP BY
  org, repo, author_email, author_name
)
GROUP BY org, repo
HAVING
  authors_alt2 > 0
  and comments > 0
  and prs > 0
  and commits > 0
  and issues > 0
ORDER BY
  authors_alt2 desc
LIMIT 1000000
;

