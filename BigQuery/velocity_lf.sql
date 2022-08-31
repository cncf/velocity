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
      'alljoyn','cip-project','cloudfoundry','cncf','codeaurora-unofficial','coreinfrastructure','Dronecode',
      'edgexafoundry','fdio-stack','fluent','fossology','frrouting','grpc','hyperledger','iovisor','iotivity',
      'JSFoundation','Kinetic','kubernetes','letsencrypt','linkerd','LinuxStandardBase','nodejs','odpi','OAI',
      'opencontainers','openmainframeproject','opensecuritycontroller','openvswitch','openchain','opendaylight',
      'openhpc','OpenMAMA','opensds','open-switch','opentracing','opnfv','pndaproject','prometheus','RConsortium',
      'rethinkdb','SNAS','spdx','todogroup','xen-project','zephyrproject-rtos', 'containerd', 'rkt', 'yoctoproject',
      'kubernetes-helm', 'kubernetes-client', 'kubernetes-incubator', 'coredns', 'grpc-ecosystem', 'cubefs',
      'containernetworking', 'crosscloudci', 'cloudevents', 'openeventing', 'envoyproxy', 'jaegertracing',
      'theupdateframework', 'rook', 'vitessio', 'telepresenceio', 'helm', 'goharbor', 'kubernetes-csi',
      'nats-io', 'open-policy-agent', 'spiffe',  'etcd-io', 'tikv', 'cortexproject', 'buildpack', 'falcosecurity',
      'OpenObservability', 'dragonflyoss', 'virtual-kubelet', 'Virtual-Kubelet', 'kubeedge', 'brigadecore',
      'kubernetes-sig-testing', 'kubernetes-providers', 'kubernetes-addons', 'kubernetes-test', 'jenkins-x',
      'kubernetes-extensions', 'kubernetes-federation', 'kubernetes-security', 'kubernetes-sigs', 'project-akri',
      'kubernetes-sidecars', 'kubernetes-tools', 'cdfoundation', 'spinnaker', 'tektoncd', 'jenkinsci',
      'iovisor', 'mininet', 'opennetworkinglab', 'p4lang', 'OpenBMP', 'tungstenfabric', 'opencord', 'Angel-ML',
      'networkservicemesh', 'cri-o', 'open-telemetry', 'openebs', 'graphql', 'thanos-io', 'fluxcd', 'zowe',
      'in-toto', 'strimzi', 'kubevirt', 'longhorn', 'chubaofs', 'fledge-iot', 'AcademySoftwareFoundation',
      'Adlik', 'MAVLink', 'MarquezProject', 'PX4', 'acumos', 'hyperledger-labs', 'mavlink', 'onnx', 'sparklyr',
      'horovod', 'pyro-ppl', 'kedacore', 'servicemeshinterface', 'argoproj', 'volcano-sh', 'crossplane-contrib',
      'cni-genie', 'keptn', 'kudobuilder', 'cloud-custodian', 'dexidp', 'artifacthub', 'parallaxsecond',
      'bfenetworks', 'crossplane', 'crossplaneio', 'litmuschaos', 'projectcontour', 'operator-framework',
      'chaos-mesh', 'serverlessworkflow', 'wayfair-tremor', 'metal3-io', 'openservicemesh', 'tremor-rs',
      'getporter', 'keylime', 'backstage', 'schemahero', 'cert-manager', 'openkruise', 'kruiseio', 'pixie-io',
      'tinkerbell', 'pravega', 'kyverno', 'buildpacks', 'gitops-working-group', 'piraeusdatastore', 'v6d-io',
      'curiefense', 'distribution', 'kubeovn', 'AthenZ', 'openyurtio', 'ingraind', 'tricksterproxy', 'foniod',
      'emissary-ingress', 'kuberhealthy', 'WasmEdge', 'chaosblade-io', 'fluid-cloudnative', 'submariner-io',
      'argoproj-labs', 'trickstercache', 'skooner-k8s', 'antrea-io', 'pixie-labs', 'layer5io', 'oam-dev',
      'kube-vip', 'service-mesh-performance', 'krator-rs', 'oras-project', 'wasmCloud', 'wascc', 'wascaruntime',
      'waxosuit', 'finos', 'chaoss', 'onap', 'o-ran-sc', 'lf-energy', 'TarsCloud', 'lfai', 'lf-edge', 'magma',
      'automotive-grade-linux', 'sodafoundation', 'riscv', 'projectacrn', 'danos', 'ceph', 'lfph', 'unikraft',
      'reactivefoundation', 'kumahq', 'k8gb-io', 'cdk8s-team', 'metallb', 'karmada-io', 'superedge', 'cilium',
      'dapr', 'open-cluster-management-io', 'nocalhost', 'kubearmor', 'k8up-io', 'kube-rs', 'k3s-io', 'o3de',
      'symphonyoss', 'sigstore', 'vscode-kubernetes-tools', 'devfile', 'meshery', 'knative', 'knative-sandbox',
      'FabEdge', 'confidential-containers', 'OpenFunction', 'clusterpedia-io', 'kubecost', 'aeraki-mesh',
      'aeraki-framewoirk', 'opencurve', 'open-feature', 'openfeatureflags', 'kubewarden', 'chimera-kube',
      'devstream-io', 'kubedl-io', 'kubevela', 'hexa-org', 'konveyor', 'external-secrets', 'krustlet', 'openembedded'
    )
    OR repo.name IN (
      'joeythesaint/cgl-specification','cncf/cross-cloud', 'deislabs/oras', 'shizhMSFT/oras',
      'cregit/cregit','diamon/diamon-www-data','JanusGraph/janusgraph', 'deislabs/krustlet',
      'brunopulis/awesome-a11y','obrienlabs/onap-root','ni/linux','Samsung/TizenRT', 'plunder-app/kube-vip',
      'docker/containerd', 'coreos/rkt', 'GoogleCloudPlatform/kubernetes', 'docker/distribution',
      'lyft/envoy', 'uber/jaeger', 'BuoyantIO/linkerd', 'apcera/nats', 'apcera/gnatsd',
      'docker/notary', 'youtube/vitess', 'appc/cni', 'miekg/coredns', 'coreos/rocket',
      'rktproject/rkt', 'datawire/telepresence', 'RichiH/OpenMetrics', 'vmware/harbor',
      'coreos/etcd', 'pingcap/tikv', 'weaveworks/cortex', 'weaveworks/prism',
      'weaveworks/frankenstein', 'draios/falco', 'alibaba/Dragonfly', 'Azure/brigade',
      'ligato/networkservicemesh', 'improbable-eng/promlts', 'improbable-eng/thanos', 'second-state/SSVM',
      'weaveworks/flux', 'EnMasseProject/barnabas', 'ppatierno/barnabas', 'ppatierno/kaas',
      'rancher/longhorn', 'containerfs/containerfs.github.io', 'containerfilesystem/cfs', 'herbrandson/k8dash',
      'containerfilesystem/doc-zh', 'PixarAnimationStudios/OpenTimelineIO', 'tomkerkhove/sample-dotnet-queue-worker',
      'tomkerkhove/sample-dotnet-queue-worker-servicebus-queue', 'tomkerkhove/sample-dotnet-worker-servicebus-queue',
      'deislabs/smi-spec', 'deislabs/smi-sdk-go', 'deislabs/smi-metrics', 'deislabs/smi-adapter-istio',
      'deislabs/smi-spec.io', 'capitalone/cloud-custodian', 'coreos/dex', 'Kong/kuma',  'Kong/kuma-website',
      'Kong/kuma-demo', 'Kong/kuma-gui', 'Kong/kumacut', 'docker/pasl', 'baidu/bfe', 'Huawei-PaaS/CNI-Genie',
      'patras-sdk/kubebuilder-maestro', 'patras-sdk/maestro', 'maestrosdk/maestro', 'maestrosdk/frameworks',
      'openebs/test-storage', 'openebs/litmus', 'cncf/hub', 'heptio/contour', 'chaos-mesh/chaos-mesh',
      'cncf/wg-serverless-workflow', 'spotify/backstage', 'deislabs/porter', 'alibaba/openyurt',
      'mit-ll/python-keylime', 'mit-ll/keylime', 'awslabs/cdk8s', 'jeststack/cert-manager',
      'jetstack-experimental/cert-manager', 'packethost/tinkerbell', 'nirmata/kyverno', 'indeedeng/k8dash',
      'yahoo/athenz', 'indeedeng/k8dash-website', 'alauda/kube-ovn', 'redsift/ingraind', 'Comcast/kuberhealthy',
      'AbsaOSS/k8gb', 'AbsaOSS/ohmyglb', 'Comcast/trickster', 'datawire/ambassador', 'alibaba/v6d',
      'alibaba/libvineyard', 'vmware-tanzu/antrea', 'cheyang/fluid', 'rancher/submariner', 'alibaba/kubedl',
      'deislabs/akri', 'danderson/metallb', 'google/metallb', 'alibaba/inclavare-containers',
      'noironetworks/cilium-net', 'kubesphere/openelb', 'kubesphere/porterlb', 'kubesphere/porter',
      'Azure/vscode-kubernetes-tools', 'accuknox/KubeArmor', 'vshn/k8up', 'clux/kube-rs', 'clux/kubernetes-rust',
      'che-incubator/devworkspace-api', 'alibaba/sealer', 'SpectralOps/teller', 'SpectralOps/helm-teller',
      'SpectralOps/setup-teller-action', 'merico-dev/stream', 'merico-dev/OpenStream', 'fusor/mig-operator',
      'G-Research/armada'
    )
  )
  and repo.name not in (
    'k3s-io/klog', 'k3s-io/containerd', 'k3s-io/cri-tools', 'k3s-io/etcd', 'k3s-io/flannel',
    'k3s-io/go-powershell', 'k3s-io/kubernetes', 'k3s-io/nocode'
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
