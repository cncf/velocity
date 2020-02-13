select
  org,
  repo,
  sum(activity) as activity,
  sum(comments) as comments,
  sum(prs) as prs,
  EXACT_COUNT_DISTINCT(sha) as commits,
  sum(issues) as issues,
  EXACT_COUNT_DISTINCT(author_email) as authors_alt2,
  GROUP_CONCAT(STRING(author_name)) AS authors_alt1,
  GROUP_CONCAT(STRING(author_email)) AS authors,
  sum(pushes) as pushes
from (
SELECT
  org.login as org,
  repo.name as repo,
  count(*) as activity,
  SUM(IF(type in ('IssueCommentEvent', 'PullRequestReviewCommentEvent', 'CommitCommentEvent'), 1, 0)) as comments,
  SUM(IF(type = 'PullRequestEvent', 1, 0)) as prs,
  SUM(IF(type = 'PushEvent', 1, 0)) as pushes,
  SUM(IF(type = 'IssuesEvent', 1, 0)) as issues,
  IFNULL(REPLACE(JSON_EXTRACT(payload, '$.commits[0].author.email'), '"', ''), '(null)') as author_email,
  IFNULL(REPLACE(JSON_EXTRACT(payload, '$.commits[0].author.name'), '"', ''), '(null)') as author_name,
  JSON_EXTRACT(payload, '$.commits[0].sha') as sha
from (
  select * from
    TABLE_DATE_RANGE([githubarchive:day.],TIMESTAMP('{{dtfrom}}'),TIMESTAMP('{{dtto}}'))
  )
WHERE
  type in ('IssueCommentEvent', 'PullRequestEvent', 'PushEvent', 'IssuesEvent', 'PullRequestReviewCommentEvent', 'CommitCommentEvent')
  AND (type = 'PushEvent' OR (type != 'PushEvent' AND JSON_EXTRACT_SCALAR(payload, '$.action') in ('created', 'opened', 'reopened')))
  AND repo.id not in (
    SELECT INTEGER(JSON_EXTRACT(payload, '$.forkee.id'))
    FROM
      TABLE_DATE_RANGE([githubarchive:day.],TIMESTAMP('{{dtfrom}}'),TIMESTAMP('{{dtto}}'))
    WHERE type = 'ForkEvent'
  )
  AND LOWER(org.login) not in ('necrobotio', 'githubschool', 'freecodecamp')
  AND LOWER(repo.name) not like '%github%school%'
  and (
    type = 'PushEvent' or (
      LOWER(actor.login) not like '%bot%'
      and actor.login != 'tgstation-server'
      and actor.login != 'openstack-gerrit'
      and actor.login not like 'k8s-%'
      and actor.login not like '%-jenkins'
      and actor.login not like '%-testing'
      and actor.login not like 'codecov-%'
      and actor.login not in (
        'CF MEGA BOT','CAPI CI','CF Buildpacks Team CI Server','CI Pool Resource','I am Groot CI','CI (automated)',
        'Loggregator CI','CI (Automated)','CI Bot','cf-infra-bot','CI','cf-loggregator','bot','CF INFRASTRUCTURE BOT',
        'CF Garden','Container Networking Bot','Routing CI (Automated)','CF-Identity','BOSH CI','CF Loggregator CI Pipeline',
        'CF Infrastructure','CI Submodule AutoUpdate','routing-ci','Concourse Bot','CF Toronto CI Bot','Concourse CI',
        'Pivotal Concourse Bot','RUNTIME OG CI','CF CredHub CI Pipeline','CF CI Pipeline','CF Identity',
        'PCF Security Enablement CI','CI BOT','Cloudops CI','hcf-bot','Cloud Foundry Buildpacks Team Robot',
        'CF CORE SERVICES BOT','PCF Security Enablement','fizzy bot','Appdog CI Bot','CF Tribe','Greenhouse CI',
        'fabric-composer-app','iotivity-replication','SecurityTest456','odl-github','opnfv-github', 'googlebot',
        'coveralls', 'rktbot', 'coreosbot', 'web-flow', 'devstats-sync','openstack-gerrit', 'openstack-gerrit',
        'prometheus-roobot', 'CNCF-bot'
      )
    )
  )
GROUP BY
  org, repo, author_email, author_name, sha
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
LIMIT 3000000
;
