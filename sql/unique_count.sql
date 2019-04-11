#standardSQL
create temp function get_subrows(json string)
returns array<string>
language js as """
  try {
    return JSON.parse(json).commits.map(commit=>commit.{{field}});
  }
  catch(error) {
    return []
  }
""";
with pushes as (
  select
    get_subrows(payload) as subrows
  from
    `githubarchive.{{table}}`
  where
    {{cond}}
    and type = 'PushEvent'
)
select
  count(distinct subrow) as unique_results
from (
  select
    subrow
  from
    pushes
  cross join
    unnest(pushes.subrows) as subrow
  where
    subrow is not null 
)
