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
select
  org.login as org,
  repo.name as repo,
  count(*) as activity,
  SUM(IF(type in ('IssueCommentEvent', 'PullRequestReviewCommentEvent', 'CommitCommentEvent'), 1, 0)) as comments,
  SUM(IF(type = 'PullRequestEvent', 1, 0)) as prs,
  SUM(IF(type = 'PushEvent', 1, 0)) as commits,
  SUM(IF(type = 'IssuesEvent', 1, 0)) as issues,
  IFNULL(REPLACE(JSON_EXTRACT(payload, '$.commits[0].author.email'), '"', ''), '(null)') as author_email,
  IFNULL(REPLACE(JSON_EXTRACT(payload, '$.commits[0].author.name'), '"', ''), '(null)') as author_name
from
  (select * from
    TABLE_DATE_RANGE([githubarchive:day.],TIMESTAMP('2017-08-01'),TIMESTAMP('2018-07-31'))
  )
where
  (
    org.login in (
      'kubernetes', 'prometheus', 'opentracing', 'fluent', 'linkerd', 'grpc', 'containerd',
      'rkt', 'kubernetes-client', 'kubernetes-helm', 'nats-io', 'open-policy-agent', 'spiffe',
      'kubernetes-incubator', 'coredns', 'grpc-ecosystem', 'containernetworking', 'cncf',
      'envoyproxy', 'jaegertracing', 'theupdateframework', 'rook', 'vitessio', 'crosscloudci',
      'cloudevents', 'openeventing', 'telepresenceio', 'helm', 'goharbor', 'kubernetes-csi',
    )
    or repo.name in (
      'docker/containerd', 'coreos/rkt', 'GoogleCloudPlatform/kubernetes', 
      'lyft/envoy', 'uber/jaeger', 'BuoyantIO/linkerd', 'apcera/nats', 'apcera/gnatsd',
      'docker/notary', 'youtube/vitess', 'appc/cni', 'miekg/coredns', 'coreos/rocket',
      'rktproject/rkt', 'datawire/telepresence', 'RichiH/OpenMetrics', 'vmware/harbor',
      'coreos/etcd'
    )
  )
  and type in ('IssueCommentEvent', 'PullRequestEvent', 'PushEvent', 'IssuesEvent', 'PullRequestReviewCommentEvent', 'CommitCommentEvent')
  and (
    type = 'PushEvent' or (
      actor.login not like 'k8s-%'
      and actor.login not like '%-bot'
      and actor.login not like '%-robot'
      and actor.login not like 'bot-%'
      and actor.login not like 'robot-%'
      and actor.login not like '%[bot]%'
      and actor.login not like '%-jenkins'
      and actor.login not like '%-ci%bot'
      and actor.login not like '%-testing'
      and actor.login not like 'codecov-%'
      and actor.login not in (
        'CF MEGA BOT', 'CAPI CI', 'CF Buildpacks Team CI Server', 'CI Pool Resource', 'I am Groot CI', 'CI (automated)',
        'Loggregator CI','CI (Automated)','CI Bot','cf-infra-bot','CI','cf-loggregator','bot','CF INFRASTRUCTURE BOT',
        'CF Garden','Container Networking Bot','Routing CI (Automated)','CF-Identity','BOSH CI','CF Loggregator CI Pipeline',
        'CF Infrastructure','CI Submodule AutoUpdate','routing-ci','Concourse Bot','CF Toronto CI Bot','Concourse CI',
        'Pivotal Concourse Bot','RUNTIME OG CI','CF CredHub CI Pipeline','CF CI Pipeline','CF Identity','PCF Security Enablement CI',
        'CI BOT','Cloudops CI','hcf-bot','Cloud Foundry Buildpacks Team Robot','CF CORE SERVICES BOT','PCF Security Enablement',
        'fizzy bot','Appdog CI Bot','CF Tribe','Greenhouse CI','fabric-composer-app','iotivity-replication','SecurityTest456',
        'odl-github','opnfv-github','googlebot', 'coveralls', 'rktbot', 'coreosbot', 'web-flow'
      )
    )
  )
group by org, repo, author_email, author_name
)
group by org, repo
order by
  activity desc
limit 100000
;
