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
    org.login IN (
      'unikraft'
    )
  )
  and type in (
    'IssueCommentEvent', 'PullRequestEvent', 'PushEvent', 'IssuesEvent',
    'PullRequestReviewCommentEvent', 'CommitCommentEvent'
  )
  and (
    type = 'PushEvent' or (
      actor.login not like 'k8s-%'
      AND NOT REGEXP_MATCH(LOWER(actor.login), r'(?s)^(?:alighrobot|amplabjenkins|angular-builds|appveyorbot|architectbot|asfgit|athenabot|atlantisbot|auto|blackduck-serv-builder|blueorangutan|bosh-ci-push-pull|buildhive|cadvisorjenkinsbot|cf-buildpacks-eng|changelogbot|ci|claude|cloudbees-pull-request-builder|clrbuilder|codelingobot|codex|codspeedbot|containersshbuilder|coreosbot|covbot|coveralls|cubic-dev-ai|cvp-ops|damn good b0t|devolutionsbot|devstats-sync|dosu|ericwittbot|fermybot|fluxcdbot|fossabot|gemini-code-assist|getporterbot|gitcoinbot|github-cncf-landscape-notifs|github-harold.pins|gocursor|goodluckbot|googlebot|gopherbot|goreleaserbot|gprasath|grafanabot|greptileai|grpc-kokoro|heptibot|hubot|infraq|intellij-rainbow-brackets|invalid-email-address|iptecharch-builder|issuehuntbot|jenkinsadmin|jfrogbot|jreleaserbot|jsdelivrbot|k3aibot|kaipilotbot|katacontainersbot|kernelprbot|krkn-chaos|kuasar-io-dev|kubescapebot|l5io|letsusegerrit|litmusbot|maxio|megaeasebot|megaeasex|mentatbot|modular-magician|monkeycode-ai|msftclas|msftgits|nsmbot|oai-codex|oceanjxbot|opencontrail-ci-admin|openebs-pro-sa|openfeaturebot|openssl-machine|opentelemetrybot|oss-sentinel-ai|oss-taishan-ai|otcbot|ovsrobot|pckgrbot|persesbot|pikbot|podmanbot|poiana|pouchrobot|projectstacker|prowbot|rancherbot|repobirdbot|rktbot|securitylab-codeanalysis|sizebot|sourcery-ai|spellarbot|spinframeworkbot|spinnakerbot|spinnakerbot2|stacklokbot|startxfr|stateful-wombot|streamnativebot|thelinuxfoundation|thinkbotbot|ti-srebot|titanium-octobot|travisbuddy|tremorbot|twbs-grunt|unownbot|vmwghbot|vsxen|waxobot|weaveworksbot|web-flow|weblate|wingetbot|yahoocla|zephyr-github|zephyrbot|actions.*|claassistant.*|cncf-bot.*|codecov.*|coderabbit.*|copilot.*|dependabot.*|github .*|github-action.*|imgbot.*|jenkins-.*|k8s-.*|mergify.*|qodo-.*|snyk.*|strimzi.*|svc.*|travis.*bot|prom.*bot|promptless.*|.*-bot|.*-robot|.*bot-.*|.*\[.*bot\].*|.*ci.*bot|.*cla.*bot.*|.*autobot|.*buildbot.*|.*copybara.*|.*renovate.*|.*envoy-filter-example.*|.*automat.*|.*agent|.*-ci|.*-gerrit|.*-infra|.*-jenkins|.*-release|.*-service.*|.*-team.*|.*-testing|.* bot|.* ci|.* team|.* releaser|.*machine account.*)$') -- devstats bots
      and actor.login not like '%-bot'
      and actor.login not like '%-robot'
      and actor.login not like 'bot-%'
      and actor.login not like 'robot-%'
      and actor.login not like '%[bot]%'
      and actor.login not like '%-jenkins'
      and actor.login not like '%-ci%bot'
      and actor.login not like '%-testing'
      and actor.login not like 'codecov-%'
      and actor.login not like '%clabot%'
      and actor.login not like '%cla-bot%'
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
        'katacontainersbot', 'prombot', 'prowbot', 'cdk8s-automation'
      )
    )
  )
GROUP BY org, repo, author_email, author_name, sha
)
GROUP BY org, repo
ORDER BY activity DESC
;
