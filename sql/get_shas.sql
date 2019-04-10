#standardSQL
create temp function get_shas(json string)
returns array<string>
language js as """
  try {
    return JSON.parse(json).commits.map(x=>x.sha);
  }
  catch(error) {
    return []
  }
""";
with pushes as (
  select
    get_shas(payload) as shas
  from
    `githubarchive.{{table}}`
  where
    type = 'PushEvent'
    and {{cond}}
)
select
  distinct sha
from
  pushes
cross join
  unnest(pushes.shas) as sha
order by
  sha
