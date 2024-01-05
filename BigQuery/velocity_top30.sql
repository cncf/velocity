select
  org,
  repo,
  sum(activity) as activity,
  sum(comments) as comments,
  sum(prs) as prs,
  EXACT_COUNT_DISTINCT(sha) as commits,
  sum(issues) as issues,
  EXACT_COUNT_DISTINCT(author_email) as authors_alt2,
  IF(LENGTH(CONCAT(GROUP_CONCAT(STRING(author_name)),GROUP_CONCAT(STRING(author_email))))>20000000,IF(SUBSTR(SUBSTR(GROUP_CONCAT(STRING(author_name)),1,10000000),-1,1)=',',SUBSTR(GROUP_CONCAT(STRING(author_name)), 1,9999999),SUBSTR(GROUP_CONCAT(STRING(author_name)),1,10000000)),GROUP_CONCAT(STRING(author_name))) as authors_alt1,
  IF(LENGTH(CONCAT(GROUP_CONCAT(STRING(author_name)),GROUP_CONCAT(STRING(author_email))))>20000000,IF(SUBSTR(SUBSTR(GROUP_CONCAT(STRING(author_email)),1,10000000),-1,1)=',',SUBSTR(GROUP_CONCAT(STRING(author_email)),1,9999999),SUBSTR(GROUP_CONCAT(STRING(author_email)),1,10000000)),GROUP_CONCAT(STRING(author_email))) as authors,
  -- GROUP_CONCAT(STRING(author_name)) AS authors_alt1,
  -- GROUP_CONCAT(STRING(author_email)) AS authors,
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
      and LOWER(actor.login) not in (
        'cf mega bot','capi ci','cf buildpacks team ci server','ci pool resource','i am groot ci','ci (automated)',
        'loggregator ci','ci (automated)','ci bot','cf-infra-bot','ci','cf-loggregator','bot','cf infrastructure bot',
        'cf garden','container networking bot','routing ci (automated)','cf-identity','bosh ci','cf loggregator ci pipeline',
        'cf infrastructure','ci submodule autoupdate','routing-ci','concourse bot','cf toronto ci bot','concourse ci',
        'pivotal concourse bot','runtime og ci','cf credhub ci pipeline','cf ci pipeline','cf identity',
        'pcf security enablement ci','ci bot','cloudops ci','hcf-bot','cloud foundry buildpacks team robot',
        'cf core services bot','pcf security enablement','fizzy bot','appdog ci bot','cf tribe','greenhouse ci',
        'fabric-composer-app','iotivity-replication','securitytest456','odl-github','opnfv-github', 'googlebot',
        'coveralls', 'rktbot', 'coreosbot', 'web-flow', 'devstats-sync','openstack-gerrit', 'openstack-gerrit',
        'prometheus-roobot', 'cncf-bot', 'github-action-benchmark', 'goreleaserbot', 'imgbotapp', 'backstage-service',
        'openssl-machine', 'sizebot', 'dependabot', 'cncf-ci', 'svcbot-qecnsdp', 'nsmbot', 'ti-srebot', 'cf-buildpacks-eng',
        'bosh-ci-push-pull', 'zephyr-github', 'zephyrbot', 'strimzi-ci', 'athenabot', 'grpc-testing', 'angular-builds',
        'hibernate-ci', 'kernelprbot', 'istio-testing', 'spinnakerbot', 'pikbot', 'spinnaker-release', 'golangcibot',
        'opencontrail-ci-admin', 'titanium-octobot', 'asfgit', 'appveyorbot', 'cadvisorjenkinsbot', 'gitcoinbot',
        'katacontainersbot', 'prombot', 'prowbot', 'cdk8s-automation', 'facebook-github-whois-bot-0', 'knative-automation',
        'covbot', 'gprasath', 'k8s-reviewable', 'claassistant', 'containersshbuilder', 'wasmcloud-automation', 'fossabot'
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
LIMIT 1000000
;
