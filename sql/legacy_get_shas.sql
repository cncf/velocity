#legacySQL
select
  exact_count_distinct(sha) as commits
from (
  select
    -- id,
    -- error,
    split(shas, ',') as sha
  from
    get_shas(
    select
      *
    from
      TABLE_DATE_RANGE([githubarchive:day.],TIMESTAMP('2018-08-01'),TIMESTAMP('2018-09-01'))
    where
      type = 'PushEvent'
      and repo.name = 'torvalds/linux'
      -- and id in ('8188163772', '8194513627', '8194515936', '8188204412', '8188232580')
  )
)
;
