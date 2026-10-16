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
select
  org.login as org,
  repo.name as repo,
  count(*) as activity,
  SUM(IF(type = 'IssueCommentEvent', 1, 0)) as comments,
  SUM(IF(type = 'PullRequestEvent', 1, 0)) as prs,
  SUM(IF(type = 'PushEvent', 1, 0)) as pushes,
  SUM(IF(type = 'IssuesEvent', 1, 0)) as issues,
  IFNULL(REPLACE(JSON_EXTRACT(payload, '$.commits[0].author.email'), '"', ''), '(null)') as author_email,
  IFNULL(REPLACE(JSON_EXTRACT(payload, '$.commits[0].author.name'), '"', ''), '(null)') as author_name,
  JSON_EXTRACT(payload, '$.commits[0].sha') as sha
from
  (select * from
    TABLE_DATE_RANGE([githubarchive:day.],TIMESTAMP('{{dtfrom}}'),TIMESTAMP('{{dtto}}'))
  )
where
  (
    org.login in (
      'FreeBSD-UPB', 'FreeBSDDesktop', 'FreeBSDFoundation', 'FreeBSDRust', 'FreeBSDWorkingBranch',
      'FreeBSDonHyper-V', 'docker-freebsd', 'freebsd', 'freebsd-build-toolkit', 'freebsd-docker',
      'freebsd-net','freebsd-riscv', 'go-freebsd', 'freebsd-haskel', 'freebsd-ext', 'freebsd-es',
      'freebsd-electron', 'freebsd-chef', 'FreeBSDChina', 'kde-freebsd', 'pbc-freebsd',
      'openstack-freebsd', 'gitlab-freebsd', 'freebsd-ita', 'zfsonfreebsd', 'FreeBSD-Ask',
      'LinuxHeartsFreeBSD', 'UIUCFreeBSD', 'freebsd-pefs', 'freebsd-store'
    )
  )
  and type in ('IssueCommentEvent', 'PullRequestEvent', 'PushEvent', 'IssuesEvent')
  and NOT REGEXP_MATCH(LOWER(actor.login), r'(?s)^(?:alighrobot|amplabjenkins|angular-builds|appveyorbot|architectbot|asfgit|athenabot|atlantisbot|auto|blackduck-serv-builder|blueorangutan|bosh-ci-push-pull|buildhive|cadvisorjenkinsbot|cf-buildpacks-eng|changelogbot|ci|claude|cloudbees-pull-request-builder|clrbuilder|codelingobot|codex|codspeedbot|containersshbuilder|coreosbot|covbot|coveralls|cubic-dev-ai|cvp-ops|damn good b0t|devolutionsbot|devstats-sync|dosu|ericwittbot|fermybot|fluxcdbot|fossabot|gemini-code-assist|getporterbot|gitcoinbot|github-cncf-landscape-notifs|github-harold.pins|gocursor|goodluckbot|googlebot|gopherbot|goreleaserbot|gprasath|grafanabot|greptileai|grpc-kokoro|heptibot|hubot|infraq|intellij-rainbow-brackets|invalid-email-address|iptecharch-builder|issuehuntbot|jenkinsadmin|jfrogbot|jreleaserbot|jsdelivrbot|k3aibot|kaipilotbot|katacontainersbot|kernelprbot|krkn-chaos|kuasar-io-dev|kubescapebot|l5io|letsusegerrit|litmusbot|maxio|megaeasebot|megaeasex|mentatbot|modular-magician|monkeycode-ai|msftclas|msftgits|nsmbot|oai-codex|oceanjxbot|opencontrail-ci-admin|openebs-pro-sa|openfeaturebot|openssl-machine|opentelemetrybot|oss-sentinel-ai|oss-taishan-ai|otcbot|ovsrobot|pckgrbot|persesbot|pikbot|podmanbot|poiana|pouchrobot|projectstacker|prowbot|rancherbot|repobirdbot|rktbot|securitylab-codeanalysis|sizebot|sourcery-ai|spellarbot|spinframeworkbot|spinnakerbot|spinnakerbot2|stacklokbot|startxfr|stateful-wombot|streamnativebot|thelinuxfoundation|thinkbotbot|ti-srebot|titanium-octobot|travisbuddy|tremorbot|twbs-grunt|unownbot|vmwghbot|vsxen|waxobot|weaveworksbot|web-flow|weblate|wingetbot|yahoocla|zephyr-github|zephyrbot|actions.*|claassistant.*|cncf-bot.*|codecov.*|coderabbit.*|copilot.*|dependabot.*|github .*|github-action.*|imgbot.*|jenkins-.*|k8s-.*|mergify.*|qodo-.*|snyk.*|strimzi.*|svc.*|travis.*bot|prom.*bot|promptless.*|.*-bot|.*-robot|.*bot-.*|.*\[.*bot\].*|.*ci.*bot|.*cla.*bot.*|.*autobot|.*buildbot.*|.*copybara.*|.*renovate.*|.*envoy-filter-example.*|.*automat.*|.*agent|.*-ci|.*-gerrit|.*-infra|.*-jenkins|.*-release|.*-service.*|.*-team.*|.*-testing|.* bot|.* ci|.* team|.* releaser|.*machine account.*)$') -- devstats bots
  AND actor.login NOT IN (
    SELECT
      actor.login
    FROM (
      SELECT
        actor.login,
        COUNT(*) c
      FROM
        TABLE_DATE_RANGE([githubarchive:day.],TIMESTAMP('{{dtfrom}}'),TIMESTAMP('{{dtto}}'))
      WHERE
        type = 'IssueCommentEvent'
      GROUP BY
        1
      HAVING
        c > 2500
      ORDER BY
      2 DESC
    )
  )
group by org, repo, author_email, author_name, sha
)
group by org, repo
order by
  activity desc
limit 10000
;
