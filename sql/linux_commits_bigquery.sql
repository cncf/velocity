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
    `githubarchive.year.2018`
  where
    repo.name = 'torvalds/linux'
)
select
  count(distinct sha) as commits
from (
  select
    sha
  FROM
    pushes
  cross join
    unnest(pushes.shas) as sha
  where
    sha is not null 
)

-- Returns 9841
