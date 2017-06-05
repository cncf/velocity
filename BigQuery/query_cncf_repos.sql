select 
  org.login as org,
  repo.name as repo
from
  [githubarchive:month.201705],
  [githubarchive:month.201611],
  [githubarchive:month.201605]
where
  org.login in (
    'kubernetes', 'prometheus', 'opentracing', 'fluent', 'linkerd', 'grpc', 'containerd',
    'rkt', 'kubernetes-client', 'kubernetes-incubator', 'coredns', 'grpc-ecosystem', 'containernetworking'
  )
  or repo.name in ('docker/containerd', 'coreos/rkt', 'GoogleCloudPlatform/kubernetes', 'GoogleCloudPlatform/kubernetes-workshops')
group by
  org, repo
order by
  org, repo
;
