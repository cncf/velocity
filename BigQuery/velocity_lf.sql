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
      'FabEdge', 'confidential-containers', 'OpenFunction', 'clusterpedia-io', 'aeraki-mesh', 'krkn-chaos',
      'aeraki-framewoirk', 'opencurve', 'open-feature', 'openfeatureflags', 'kubewarden', 'chimera-kube',
      'devstream-io', 'kubedl-io', 'kubevela', 'hexa-org', 'konveyor', 'external-secrets', 'krustlet', 'openembedded',
      'Serverless-Devs', 'ServerlessTool', 'ContainerSSH', 'openfga', 'lima-vm', 'k14s', 'kubereboot', 'istio',
      'inclavare-containers', 'notaryproject', 'merbridge', 'devspace-cloud', 'covexo', 'project-zot', 'oauth2-proxy',
      'paralus', 'carina-io', 'ko-build', 'opcr-io', 'werf', 'kubescape', 'openelb', 'tektoncd-catalog', 'opencost',
      'carvel-dev', 'inspektor-gadget', 'clusternet', 'cdevents', 'ortelius', 'pyrsia', 'screwdriver-cd',
      'shipwright-io', 'sealerio', 'keycloak', 'armadaproject', 'devspace-sh', 'tellerops', 'headlamp-k8s',
      'slimtoolkit', 'sockerslim', 'sustainable-computing-io', 'pipe-cd', 'xline-kv', 'hwameistor', 'microcks',
      'kubeclipper', 'kubeclipper-labs', 'kubeflow', 'buildpacks-community', 'getsops', 'eraser-dev', 'kserve',
      'knative-extensions', 'project-copacetic', 'kube-logging', 'kanisterio', 'kcp-dev', 'kcl-lang', 'projectcapsule',
      'kube-burner', 'kuasar-io', 'redchat-chaos', 'kubestellar', 'megaease', 'spidernet-io', 'k8sgpt-ai',
      'chaos-kubox', 'KubeStellar', 'kptdev', 'redhat-chaos', 'OpenMetrics', 'openmetrics', 'open-gitops',
      'kubeslice', 'connectrpc', 'kairos-io', 'c3os-io', 'kubean-io', 'koordinator-sh', 'radius-project', 'HolmesGPT',
      'easegress-io', 'bank-vaults', 'runatlantis', 'project-stacker', 'oscal-compass', 'Kuadrant', 'openGemini',
      'score-spec', 'bpfman', 'bpfd-dev', 'pytorch', 'loxilb-io', 'perses', 'ratify-project', 'Project-HAMi',
      'flatcar', 'flatcar-linux', 'KusionStack', 'cartography-cncf', 'cncf-tags', 'youki-dev', 'kaito-project',
      'sermant-io', 'kmesh-net', 'ovn-org', 'prometheus-community', 'tratteria', 'spinkube', 'k0sproject',
      'cloudnative-pg', 'podman-desktop', 'drasi-project', 'ovn-kubernetes', 'kgateway-dev', 'k8sgateway',
      'hyperlight-dev', 'cozystack', 'kitops-ml', 'SlimPlanet', 'spinframework', 'container2wasm', 'modelpack',
      'runmedev', 'tokenetes', 'bootc-dev', 'composefs', 'kubefleet-dev', 'meshery-extensions', 'opentofu',
      'opentffoundation', 'openterraform', 'cadence-workflow', 'kagent-dev', 'urunc-dev', 'xregistry', 'CloudNativeAI',
      'oxia-db', 'cedar-policy', 'project-dalec', 'interlink-hq'
    )
    OR repo.name IN (
      'joeythesaint/cgl-specification','cncf/cross-cloud', 'deislabs/oras', 'shizhMSFT/oras',
      'cregit/cregit','diamon/diamon-www-data','JanusGraph/janusgraph', 'deislabs/krustlet',
      'brunopulis/awesome-a11y','obrienlabs/onap-root','ni/linux','Samsung/TizenRT', 'plunder-app/kube-vip',
      'docker/containerd', 'coreos/rkt', 'GoogleCloudPlatform/kubernetes', 'docker/distribution',
      'lyft/envoy', 'uber/jaeger', 'BuoyantIO/linkerd', 'apcera/nats', 'apcera/gnatsd', 'loft-sh/devspace',
      'docker/notary', 'youtube/vitess', 'appc/cni', 'miekg/coredns', 'coreos/rocket',
      'rktproject/rkt', 'datawire/telepresence', 'RichiH/OpenMetrics', 'vmware/harbor',
      'coreos/etcd', 'pingcap/tikv', 'weaveworks/cortex', 'weaveworks/prism', 'redhat-developer/build',
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
      'G-Research/armada', 'janoszen/ContainerSSH', 'janoszen/containerssh', 'weaveworks/kured',
      'vmware-tanzu/carvel', 'vmware-tanzu/carvel-kapp-controller', 'vmware-tanzu/carvel-kapp',
      'vmware-tanzu/carvel-ytt', 'vmware-tanzu/carvel-imgpkg', 'vmware-tanzu/carvel-kbld',
      'vmware-tanzu/carvel-vendir', 'vmware-tanzu/carvel-kwt', 'vmware-tanzu/carvel-secretgen-controller',
      'AkihiroSuda/lima', 'kebe7jun/mepf', 'kebe7jun/mebpf', 'anuvu/zot', 'google/ko', 'flant/werf', 'flant/dapp',
      'flant/dapper', 'armosec/kubescape', 'kinvolk/inspektor-gadget', 'redhat-developer/buildv2',
      'redhat-developer/buildv2-operator', 'clastix/capsule', 'clastix/capsule-proxy', ' cncf/sig-app-delivery',
      'clastix/capsule-addon-rancher', 'clastix/capsule-community', 'clastix/capsule-addon-cloudcasa',
      'clastix/capsule-k8s-charm', 'clastix/clastix/capsule-lens-extension', 'clastix/capsule-helm-chart',
      'clastix/flux2-capsule-multi-tenancy', 'clastix/capsule-ns-filter', 'clastix/Capsule',
      'clastix/ckd-capsule-app', 'cncf/tag-app-delivery', 'mozilla/sops', 'mozilla/sotp', 'mozilla-services/sosp',
      'kinvolk/headlamp', 'cloudimmunity/docker-slim', 'Azure/eraser', 'datenlord/Xline', 'GoogleContainerTools/kpt',
      'cloud-bulldozer/kube-burner', 'cloud-bulldozer/rosa-burner', 'cloud-bulldozer/krkn',
      'cloud-bulldozer/kraken', 'openshift-scale/kraken', 'kcp-dev/edge-mc', 'bufbuild/connect-go', 'bufbuild/rerpc',
      'rerpc/rerpc', 'mudler/c3os', 'banzaicloud/bank-vaults', 'banzaicloud/vault-dogsbody', 'atlantisnorth/atlantis',
      'anuvu/stacker', 'IBM/compliance-trestle', '3scale-labs/authorino', 'redhat-et/bpfd', 'lyft/cartography',
      'deislabs/ratify', 'deislabs/ratify-web', 'deislabs/ratify-action', 'kinvolk/Flatcar',
      'kinvolk/flatcar-scripts', 'kinvolk/mantle', 'google/kubeflow', 'banzaicloud/logging-operator',
      'containers/youki', 'utam0k/youki', 'Azure/kaito', 'huaweicloud/Sermant', 'huaweicloud/java-mesh',
      'huaweicloud/JavaMesh', 'openvswitch/ovn-kubernetes', 'fermyon/spin', 'fermyon/spin-python-sdk',
      'fermyon/spin-js-sdk', 'fermyon/spin-rust-sdk', 'fermyon/spin-dotnet-sdk', 'fermyon/spin-nim-sdk',
      'fermyon/spin-plugins', 'fermyon/spin-test', 'fermyon/platform-plugin', 'AxaFrance/SlimFaas',
      'fermyon/spin-trigger-command', 'fermyon/spin-trigger-sqs', 'fermyon/spin-trigger-cron',
      'ktock/container2wasm', 'stateful/runme', 'stateful/runme.dev', 'stateful/runmejs',
      'stateful/runme-web-extension', 'stateful/runme-action', 'stateful/docs.runme.dev',
      'stateful/runme-action-examples', 'stateful/mkdocs-runme-plugin', 'stateful/Runme-CDEs',
      'stateful/runme-terramate-aws', 'stateful/terramate-runme-example', 'uber/cadence',
      'stateful/runme-terramate-example', 'stateful/runme-foyle-ai', 'Azure/Fleet-PRSE',
      'Azure/fleet-networking', 'Azure/fleet', 'Azure/azure-rest-api-specs-fleet', 'pusher/oauth2_proxy',
      'containers/podman', 'containers/buildah', 'containers/skopeo', 'containers/netavark',
      'containers/aardvark-dns', 'containers/image', 'containers/storage', 'containers/common',
      'containers/conmon', 'containers/podman-py', 'containers/bootc', 'containers/composefs',
      'interTwin-eu/interLink', 'interTwin-eu/vk-test-set', 'interTwin-eu/interlink-jhub',
      'interTwin-eu/interlink-slurm-plugin', 'interTwin-eu/interlink-docker-plugin',
      'interTwin-eu/interlink-helm-chart', 'interTwin-eu/interlink-monitoring-stack',
      'interTwin-eu/interlink-htcondor-plugin', 'interTwin-eu/interlink-kueue-plugin',
      'interTwin-eu/interlink-arc-plugin', 'interTwin-eu/interlink-unicore-plugin', 'aenix-io/etcd-operator',
      'aenix-io/talm', 'aenix-io/talos-bootstrap', 'aeniz-io/cozystack', 'aenix-io/kubernetes-in-kubernetes',
      'aenix-io/kubefarm', 'aenix-io/cozystack-website', 'aenix-io/cozy-proxy', 'aenix-io/cozystack-telemetry-server',
      'jozu-ai/kitops', 'aenix-io/cozystack-gitops-example', 'jozu-ai/gh-kit-setup', 'jozu-ai/daggerverse',
      'jozu-ai/pykitops', 'solo-io/gloo', 'kubernetes-purgatory/headlamp', 'nubificus/urunc',
      'streamnative/oxia', 'Azure/dalec', 'robusta-dev/holmesgpt', 'robusta-dev/homebrew-holmesgpt',
      'robusta-dev/holmesgpt-community-toolsets'
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
