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
  SUM(IF(type in ('IssueCommentEvent', 'PullRequestReviewCommentEvent', 'CommitCommentEvent'), 1, 0)) as comments,
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
      'kubernetes', 'prometheus', 'opentracing', 'fluent', 'linkerd', 'grpc', 'containerd',
      'rkt', 'kubernetes-client', 'kubernetes-helm', 'nats-io', 'open-policy-agent', 'spiffe',
      'kubernetes-incubator', 'coredns', 'grpc-ecosystem', 'containernetworking', 'cncf',
      'envoyproxy', 'jaegertracing', 'theupdateframework', 'rook', 'vitessio', 'crosscloudci',
      'cloudevents', 'openeventing', 'telepresenceio', 'helm', 'goharbor', 'kubernetes-csi',
      'etcd-io', 'tikv', 'cortexproject', 'buildpack', 'falcosecurity', 'OpenObservability',
      'dragonflyoss', 'virtual-kubelet', 'Virtual-Kubelet', 'kubeedge', 'brigadecore',
      'kubernetes-sig-testing', 'kubernetes-providers', 'kubernetes-addons', 'kubernetes-test',
      'kubernetes-extensions', 'kubernetes-federation', 'kubernetes-security', 'kubernetes-sigs',
      'kubernetes-sidecars', 'kubernetes-tools', 'cdfoundation', 'cri-o', 'networkservicemesh',
      'open-telemetry', 'openebs', 'thanos-io', 'fluxcd', 'in-toto', 'strimzi', 'kubevirt',
      'longhorn', 'chubaofs', 'kedacore', 'servicemeshinterface', 'argoproj', 'volcano-sh', 'v6d-io',
      'cni-genie', 'keptn', 'kudobuilder', 'cloud-custodian', 'dexidp', 'artifacthub', 'parallaxsecond',
      'bfenetworks', 'crossplane', 'crossplaneio', 'litmuschaos', 'projectcontour', 'operator-framework',
      'chaos-mesh', 'serverlessworkflow', 'wayfair-tremor', 'metal3-io', 'openservicemesh', 'tremor-rs',
      'getporter', 'keylime', 'backstage', 'schemahero', 'cert-manager', 'openkruise', 'kruiseio',
      'tinkerbell', 'pravega', 'kyverno', 'buildpacks', 'gitops-working-group', 'piraeusdatastore',
      'curiefense', 'distribution', 'kubeovn', 'AthenZ', 'openyurtio', 'ingraind', 'tricksterproxy',
      'foniod', 'emissary-ingress', 'kuberhealthy', 'WasmEdge', 'chaosblade-io', 'fluid-cloudnative',
      'submariner-io', 'argoproj-labs', 'trickstercache', 'skooner-k8s', 'antrea-io', 'pixie-labs',
      'layer5io', 'oam-dev', 'kube-vip', 'service-mesh-performance', 'krator-rs', 'oras-project',
      'wasmCloud', 'wascc', 'wascaruntime', 'waxosuit', 'kumahq', 'k8gb-io', 'cdk8s-team'
    )
    or repo.name in (
      'docker/containerd', 'coreos/rkt', 'GoogleCloudPlatform/kubernetes', 
      'lyft/envoy', 'uber/jaeger', 'BuoyantIO/linkerd', 'apcera/nats', 'apcera/gnatsd',
      'docker/notary', 'youtube/vitess', 'appc/cni', 'miekg/coredns', 'coreos/rocket',
      'rktproject/rkt', 'datawire/telepresence', 'RichiH/OpenMetrics', 'vmware/harbor',
      'coreos/etcd', 'pingcap/tikv', 'weaveworks/cortex', 'weaveworks/prism',
      'weaveworks/frankenstein', 'draios/falco', 'alibaba/Dragonfly', 'Azure/brigade',
      'ligato/networkservicemesh', 'improbable-eng/promlts', 'improbable-eng/thanos',
      'weaveworks/flux', 'EnMasseProject/barnabas', 'ppatierno/barnabas',' ppatierno/kaas',
      'rancher/longhorn', 'containerfs/containerfs.github.io', 'containerfilesystem/cfs',
      'containerfilesystem/doc-zh', 'tomkerkhove/sample-dotnet-queue-worker',
      'tomkerkhove/sample-dotnet-queue-worker-servicebus-queue', 'plunder-app/kube-vip',
      'tomkerkhove/sample-dotnet-worker-servicebus-queue', 'deislabs/smi-spec',
      'deislabs/smi-sdk-go', 'deislabs/smi-metrics', 'deislabs/smi-adapter-istio', 'herbrandson/k8dash',
      'deislabs/smi-spec.io', 'capitalone/cloud-custodian', 'coreos/dex', 'Kong/kuma',  'Kong/kuma-website',
      'Kong/kuma-demo', 'Kong/kuma-gui', 'Kong/kumacut', 'docker/pasl', 'baidu/bfe', 'Huawei-PaaS/CNI-Genie',
      'patras-sdk/kubebuilder-maestro', 'patras-sdk/maestro', 'maestrosdk/maestro', 'maestrosdk/frameworks',
      'openebs/test-storage', 'openebs/litmus', 'cncf/hub', 'heptio/contour', 'chaos-mesh/chaos-mesh',
      'cncf/wg-serverless-workflow', 'rancher/k3s', 'rancher/k3d', 'rancher/k3s-ansible', 'rancher/k3s-root',
      'rancher/k3s-upgrade', 'rancher/k3s-selinux', 'rancher/terraform-k3s-aws-cluster', 'ibuildthecloud/k3s-root',
      'ibuildthecloud/k3s-dev', 'ibuildthecloud/k3d', 'spotify/backstage', 'deislabs/porter', 'alibaba/openyurt',
      'mit-ll/python-keylime', 'mit-ll/keylime', 'awslabs/cdk8s', 'jeststack/cert-manager',
      'jetstack-experimental/cert-manager', 'packethost/tinkerbell', 'nirmata/kyverno', 'indeedeng/k8dash',
      'yahoo/athenz', 'indeedeng/k8dash-website', 'alauda/kube-ovn', 'redsift/ingraind', 'Comcast/kuberhealthy',
      'AbsaOSS/k8gb', 'AbsaOSS/ohmyglb', 'Comcast/trickster', 'datawire/ambassador', 'alibaba/v6d',
      'alibaba/libvineyard', 'vmware-tanzu/antrea', 'cheyang/fluid', 'rancher/submariner', 'alibaba/kubedl',
      'deislabs/krustlet', 'deislabs/oras', 'shizhMSFT/oras', 'docker/distribution', 'second-state/SSVM'
    )
  )
  and type in (
    'IssueCommentEvent', 'PullRequestEvent', 'PushEvent', 'IssuesEvent',
    'PullRequestReviewCommentEvent', 'CommitCommentEvent'
  )
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
      and actor.login not like '%clabot%'
      and actor.login not like '%cla-bot%'
      and actor.login not in (
        'CF MEGA BOT', 'CAPI CI', 'CF Buildpacks Team CI Server', 'CI Pool Resource', 'I am Groot CI', 'CI (automated)',
        'Loggregator CI','CI (Automated)','CI Bot','cf-infra-bot','CI','cf-loggregator','bot','CF INFRASTRUCTURE BOT',
        'CF Garden','Container Networking Bot','Routing CI (Automated)','CF-Identity','BOSH CI','CF Loggregator CI Pipeline',
        'CF Infrastructure','CI Submodule AutoUpdate','routing-ci','Concourse Bot','CF Toronto CI Bot','Concourse CI',
        'Pivotal Concourse Bot','RUNTIME OG CI','CF CredHub CI Pipeline','CF CI Pipeline','CF Identity','PCF Security Enablement CI',
        'CI BOT','Cloudops CI','hcf-bot','Cloud Foundry Buildpacks Team Robot','CF CORE SERVICES BOT','PCF Security Enablement',
        'fizzy bot','Appdog CI Bot','CF Tribe','Greenhouse CI','fabric-composer-app','iotivity-replication','SecurityTest456',
        'odl-github','opnfv-github','googlebot', 'coveralls', 'rktbot', 'coreosbot', 'web-flow', 'devstats-sync','openstack-gerrit',
        'openstack-gerrit', 'prometheus-roobot', 'CNCF-bot'
      )
    )
  )
group by org, repo, author_email, author_name, sha
)
group by org, repo
order by
  activity desc
limit 1000000
;
