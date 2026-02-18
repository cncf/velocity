#standardSQL
-- typical commits/commit authors ration in 254k repos: authors(sum)=4483902 commits(sum)=84078359 -> 18.75
-- typical repo clone failure rate in 254k repos=254248 failed=9528 -> 3.75%
WITH base AS (
  SELECT
    id,
    repo.name AS repo,
    -- org.login AS org,
    COALESCE(org.login, SPLIT(repo.name, '/')[SAFE_OFFSET(0)]) AS org,
    type,
    actor.login AS actor,
    payload
  FROM
    `githubarchive.day.20*`
  WHERE
    _TABLE_SUFFIX BETWEEN '{{dtfrom}}' AND '{{dtto}}'
    AND type IN (
      'PushEvent', 'PullRequestEvent', 'IssuesEvent', 'PullRequestReviewEvent',
      'CommitCommentEvent', 'IssueCommentEvent', 'PullRequestReviewCommentEvent'
    )
    AND actor.login NOT LIKE 'k8s-%'
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
), agg AS (
  SELECT
    b.org,
    b.repo,
    COUNT(DISTINCT b.id) AS activity,
    COUNT(DISTINCT IF(b.type IN ('IssueCommentEvent', 'PullRequestReviewCommentEvent', 'CommitCommentEvent', 'PullRequestReviewEvent'), b.id, NULL)) AS comments,
    COUNT(DISTINCT IF(b.type = 'PullRequestEvent', b.id, NULL)) AS prs,
    COUNT(DISTINCT IF(b.type = 'IssuesEvent', b.id, NULL)) AS issues,
    COUNT(DISTINCT IF(b.type = 'PushEvent', b.id, NULL)) AS pushes,
    COUNT(DISTINCT IF(b.type = 'PullRequestEvent' AND LOWER(JSON_VALUE(payload, '$.action')) = 'opened', b.actor, NULL)) AS pr_openers,
    COUNT(DISTINCT IF(b.type = 'IssuesEvent' AND LOWER(JSON_VALUE(payload, '$.action')) = 'opened', b.actor, NULL)) AS issue_openers,
    COUNT(DISTINCT IF(b.type IN ('IssueCommentEvent', 'PullRequestReviewCommentEvent', 'CommitCommentEvent', 'PullRequestReviewEvent'), b.actor, NULL)) AS commenters,
    COUNT(DISTINCT IF(b.type = 'PushEvent', b.actor, NULL)) AS pushers,
  FROM
    base b
  GROUP BY
    b.org, b.repo
  HAVING
    comments > 0
    and prs > 0
    and issues > 0
    and pushes > 0
), scored AS (
  SELECT
    *,
    (pr_openers + issue_openers + commenters + pushers + ((prs + issues + comments + pushes) / 19)) AS score
  FROM
    agg
), candidates_raw AS (
  SELECT org, repo FROM (SELECT org, repo FROM scored ORDER BY score DESC LIMIT 222222)
  UNION ALL
  SELECT org, repo FROM (SELECT org, repo FROM scored ORDER BY pr_openers DESC LIMIT 222222)
  UNION ALL
  SELECT org, repo FROM (SELECT org, repo FROM scored ORDER BY issue_openers DESC LIMIT 222222)
  UNION ALL
  SELECT org, repo FROM (SELECT org, repo FROM scored ORDER BY commenters DESC LIMIT 222222)
  UNION ALL
  SELECT org, repo FROM (SELECT org, repo FROM scored ORDER BY pushers DESC LIMIT 222222)
  UNION ALL
  SELECT org, repo FROM (SELECT org, repo FROM scored ORDER BY prs DESC LIMIT 222222)
  UNION ALL
  SELECT org, repo FROM (SELECT org, repo FROM scored ORDER BY issues DESC LIMIT 222222)
  UNION ALL
  SELECT org, repo FROM (SELECT org, repo FROM scored ORDER BY comments DESC LIMIT 222222)
  UNION ALL
  SELECT org, repo FROM (SELECT org, repo FROM scored ORDER BY pushes DESC LIMIT 222222)
), candidates AS (
  SELECT DISTINCT org, repo
  FROM candidates_raw
)
SELECT
  s.org,
  s.repo,
  s.activity,
  s.comments,
  s.prs,
  0 AS commits,
  s.issues,
  0 AS authors_alt2,
  '' AS authors_alt1,
  '' AS authors,
  s.pushes
FROM
  scored s
JOIN
  candidates c
ON
  s.org = c.org AND s.repo = c.repo
ORDER BY
  s.score DESC
;
