select
  count(*) as activity,
  SUM(IF(type = 'IssueCommentEvent', 1, 0)) as comments,
  SUM(IF(type = 'PullRequestEvent', 1, 0)) as prs,
  SUM(IF(type = 'PushEvent', 1, 0)) as commits,
  SUM(IF(type = 'IssuesEvent', 1, 0)) as issues,
  IFNULL(REPLACE(JSON_EXTRACT(payload, '$.commits[0].author.name'), '"', ''), '(null)') as author_name
from  (select * from    TABLE_DATE_RANGE([githubarchive:day.],TIMESTAMP('2016-11-01'),TIMESTAMP('2017-10-31'))  )
where
  org.login in ('cloudfoundry', 'cloudfoundry-attic', 'cloudfoundry-community', 'cloudfoundry-incubator', 'cloudfoundry-samples')
  and type in ('IssueCommentEvent', 'PullRequestEvent', 'PushEvent', 'IssuesEvent')
  AND LOWER(actor.login) not like '%bot%'
  AND LOWER(actor.login) not like '%cf-%'
  AND LOWER(actor.login) not in ('pubtools-doc-helper', 'routing-ci', 'runtime-ci', 'cf-buildpacks-eng', 'coveralls', 'garden-gnome',
  'flintstonecf', 'CI Pool Resource', 'CF Buildpacks Team CI Server', 'CF MEGA BOT', 'git', 'I am Groot CI', 'CI (Automated)',
  'CI (automated)', 'CI Bot', 'Loggregator CI', 'CI', 'CF INFRASTRUCTURE BOT', 'bot', 'CAPI CI', 'cf-loggregator', 'BOSH CI', 'persi-ci',
  'CF Loggregator CI Pipeline', 'CI Submodule AutoUpdate', 'CF-Identity', 'Concourse CI', 'Greenhouse CI', 'cf-infra-bot',
  'Pivotal Concourse Bot')
group by author_name
order by activity desc
limit 10000
;
