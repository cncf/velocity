select 
  org.login as org
from
  [githubarchive:month.201704],
  [githubarchive:month.201610],
  [githubarchive:month.201604]
where
  LOWER(org.login) like '%open%stack%'
group by
  org
order by
  org
;
