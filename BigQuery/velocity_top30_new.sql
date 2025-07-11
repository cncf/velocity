#standardSQL
WITH base AS (
  SELECT
    id,
    repo.name AS repo,
    org.login AS org,
    type,
    payload
  FROM
    `githubarchive.day.20*`
  WHERE
    _TABLE_SUFFIX BETWEEN '{{dtfrom}}' AND '{{dtto}}'
    AND type IN (
      'PushEvent', 'PullRequestEvent', 'IssuesEvent', 'PullRequestReviewEvent',
      'CommitCommentEvent', 'IssueCommentEvent', 'PullRequestReviewCommentEvent'
    )
    AND (
      type = 'PushEvent' OR (
        actor.login NOT LIKE 'k8s-%'
        AND actor.login NOT LIKE '%-bot'
        AND actor.login NOT LIKE '%-robot'
        AND actor.login NOT LIKE 'bot-%'
        AND actor.login NOT LIKE 'robot-%'
        AND actor.login NOT LIKE '%[bot]%'
        AND actor.login NOT LIKE '%-bot-%'
        AND actor.login NOT LIKE '%-jenkins'
        AND actor.login NOT LIKE 'jenkins-%'
        AND actor.login NOT LIKE '%-ci%bot'
        AND actor.login NOT LIKE '%-testing'
        AND actor.login NOT LIKE 'codecov-%'
        AND actor.login NOT LIKE '%clabot%'
        AND actor.login NOT LIKE '%cla-bot%'
        AND actor.login NOT LIKE 'travis%bot'
        AND actor.login NOT LIKE '%[robot]%'
        AND actor.login NOT LIKE '%-gerrit'
        AND actor.login NOT LIKE '%envoy-filter-example%'
        AND actor.login NOT LIKE '%cibot'
        AND actor.login NOT LIKE '%-ci'
        AND LOWER(actor.login) NOT IN (
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
          'katacontainersbot', 'prombot', 'prowbot', 'cdk8s-automation', 'openebs-pro-sa', 'stateful-wombot', 'fermybot',
          'opentofu-provider-sync-service-account', 'flatcar-infra', 'atlantisbot', 'megaeasex', 'kuasar-io-dev', 'startxfr',
          'opentelemetrybot', 'invalid-email-address', 'fluxcdbot', 'claassistant', 'containersshbuilder', 'wasmcloud-automation',
          'fossabot', 'knative-automation', 'covbot', 'poiana', 'gprasath', 'k8s-reviewable', 'codecov-io', 'k8s-teamcity-mesosphere'
        )
      )
    )
),
commits_flat AS (
  SELECT
    id,
    JSON_VALUE(commit, '$.sha') AS sha,
    NULLIF(LOWER(TRIM(REPLACE(JSON_VALUE(commit, '$.author.email'), '"', ''))), '') AS author_email,
    NULLIF(LOWER(TRIM(REPLACE(JSON_VALUE(commit, '$.author.name'), '"', ''))), '') AS author_name
  FROM
    base,
    UNNEST(JSON_EXTRACT_ARRAY(payload, '$.commits')) AS commit
  WHERE
    type = 'PushEvent'
)
SELECT
  b.org,
  b.repo,
  COUNT(DISTINCT b.id) AS activity,
  COUNT(DISTINCT IF(b.type IN ('IssueCommentEvent', 'PullRequestReviewCommentEvent', 'CommitCommentEvent', 'PullRequestReviewEvent'), b.id, NULL)) AS comments,
  COUNT(DISTINCT IF(b.type = 'PullRequestEvent', b.id, NULL)) AS prs,
  COUNT(DISTINCT c.sha) AS commits,
  COUNT(DISTINCT IF(b.type = 'IssuesEvent', b.id, NULL)) AS issues,
  COUNT(DISTINCT c.author_email) AS authors_alt2,
  STRING_AGG(DISTINCT c.author_name) AS authors_alt1,
  STRING_AGG(DISTINCT c.author_email) AS authors,
  COUNT(DISTINCT IF(b.type = 'PushEvent', b.id, NULL)) AS pushes
FROM
  base b
LEFT JOIN
  commits_flat c
ON
  b.id = c.id
GROUP BY
  b.org, b.repo
HAVING
  authors_alt2 > 0
  and comments > 0
  and prs > 0
  and commits > 0
  and issues > 0
ORDER BY
  authors_alt2 DESC
LIMIT
  5000000
