select 
  {{actor}},
  count(distinct sha) as commits
from
  gha_commits
where
  lower({{actor}}) {{exclude_bots}}
  and author_name not in
(
'CI Pool Resource',
'CF Buildpacks Team CI Server',
'CAPI CI',
'CF MEGA BOT',
'I am Groot CI',
'CI (automated)',
'Loggregator CI',
'CI (Automated)',
'CI Bot',
'cf-infra-bot',
'CI',
'cf-loggregator',
'bot',
'CF INFRASTRUCTURE BOT',
'CF Garden',
'Container Networking Bot',
'Routing CI (Automated)',
'CF-Identity',
'BOSH CI',
'CF Loggregator CI Pipeline',
'CF Infrastructure',
'CI Submodule AutoUpdate',
'routing-ci',
'Concourse Bot',
'CF Toronto CI Bot',
'Concourse CI',
'Pivotal Concourse Bot',
'RUNTIME OG CI',
'CF CredHub CI Pipeline',
'CF CI Pipeline',
'CF Identity',
'PCF Security Enablement CI',
'CI BOT',
'Cloudops CI',
'hcf-bot',
'Cloud Foundry Buildpacks Team Robot',
'CF CORE SERVICES BOT',
'PCF Security Enablement',
'fizzy bot',
'Appdog CI Bot',
'CF Tribe',
'Greenhouse CI'
)
  and committer_name not in
(
'CI Pool Resource',
'CF Buildpacks Team CI Server',
'CAPI CI',
'CF MEGA BOT',
'I am Groot CI',
'CI (automated)',
'Loggregator CI',
'CI (Automated)',
'CI Bot',
'cf-infra-bot',
'CI',
'cf-loggregator',
'bot',
'CF INFRASTRUCTURE BOT',
'CF Garden',
'Container Networking Bot',
'Routing CI (Automated)',
'CF-Identity',
'BOSH CI',
'CF Loggregator CI Pipeline',
'CF Infrastructure',
'CI Submodule AutoUpdate',
'routing-ci',
'Concourse Bot',
'CF Toronto CI Bot',
'Concourse CI',
'Pivotal Concourse Bot',
'RUNTIME OG CI',
'CF CredHub CI Pipeline',
'CF CI Pipeline',
'CF Identity',
'PCF Security Enablement CI',
'CI BOT',
'Cloudops CI',
'hcf-bot',
'Cloud Foundry Buildpacks Team Robot',
'CF CORE SERVICES BOT',
'PCF Security Enablement',
'fizzy bot',
'Appdog CI Bot',
'CF Tribe',
'Greenhouse CI'
)
group by
  {{actor}}
order by
  commits desc
limit
  50
;
