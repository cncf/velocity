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
        AND NOT REGEXP_CONTAINS(LOWER(actor.login), r'(?s)^(?:alighrobot|amplabjenkins|angular-builds|appveyorbot|architectbot|asfgit|athenabot|atlantisbot|auto|blackduck-serv-builder|blueorangutan|bosh-ci-push-pull|buildhive|cadvisorjenkinsbot|cf-buildpacks-eng|changelogbot|ci|claude|cloudbees-pull-request-builder|clrbuilder|codelingobot|codex|codspeedbot|containersshbuilder|coreosbot|covbot|coveralls|cubic-dev-ai|cvp-ops|damn good b0t|devolutionsbot|devstats-sync|dosu|ericwittbot|fermybot|fluxcdbot|fossabot|gemini-code-assist|getporterbot|gitcoinbot|github-cncf-landscape-notifs|github-harold.pins|gocursor|goodluckbot|googlebot|gopherbot|goreleaserbot|gprasath|grafanabot|greptileai|grpc-kokoro|heptibot|hubot|infraq|intellij-rainbow-brackets|invalid-email-address|iptecharch-builder|issuehuntbot|jenkinsadmin|jfrogbot|jreleaserbot|jsdelivrbot|k3aibot|kaipilotbot|katacontainersbot|kernelprbot|krkn-chaos|kuasar-io-dev|kubescapebot|l5io|letsusegerrit|litmusbot|maxio|megaeasebot|megaeasex|mentatbot|modular-magician|monkeycode-ai|msftclas|msftgits|nsmbot|oai-codex|oceanjxbot|opencontrail-ci-admin|openebs-pro-sa|openfeaturebot|openssl-machine|opentelemetrybot|oss-sentinel-ai|oss-taishan-ai|otcbot|ovsrobot|pckgrbot|persesbot|pikbot|podmanbot|poiana|pouchrobot|projectstacker|prowbot|rancherbot|repobirdbot|rktbot|securitylab-codeanalysis|sizebot|sourcery-ai|spellarbot|spinframeworkbot|spinnakerbot|spinnakerbot2|stacklokbot|startxfr|stateful-wombot|streamnativebot|thelinuxfoundation|thinkbotbot|ti-srebot|titanium-octobot|travisbuddy|tremorbot|twbs-grunt|unownbot|vmwghbot|vsxen|waxobot|weaveworksbot|web-flow|weblate|wingetbot|yahoocla|zephyr-github|zephyrbot|actions.*|claassistant.*|cncf-bot.*|codecov.*|coderabbit.*|copilot.*|dependabot.*|github .*|github-action.*|imgbot.*|jenkins-.*|k8s-.*|mergify.*|qodo-.*|snyk.*|strimzi.*|svc.*|travis.*bot|prom.*bot|promptless.*|.*-bot|.*-robot|.*bot-.*|.*\[.*bot\].*|.*ci.*bot|.*cla.*bot.*|.*autobot|.*buildbot.*|.*copybara.*|.*renovate.*|.*envoy-filter-example.*|.*automat.*|.*agent|.*-ci|.*-gerrit|.*-infra|.*-jenkins|.*-release|.*-service.*|.*-team.*|.*-testing|.* bot|.* ci|.* team|.* releaser|.*machine account.*)$') -- devstats bots
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
          'fossabot', 'knative-automation', 'covbot', 'poiana', 'gprasath', 'k8s-reviewable', 'codecov-io', 'k8s-teamcity-mesosphere',
          'copilot', 'claude', 'codex'
        )
      )
    ) AND (
    {{cond}}
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
ORDER BY
  activity DESC
