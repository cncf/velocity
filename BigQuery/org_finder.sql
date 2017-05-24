select 
  org.login as org
from
  [githubarchive:month.201704]
where
  LOWER(org.login) like '%open%stack%'
group by
  org
order by
  org
;
