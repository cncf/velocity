select 
  org.login as org
from
  [githubarchive:month.202001],
  [githubarchive:month.201904],
  [githubarchive:month.201804],
  [githubarchive:month.201704],
  [githubarchive:month.201604],
  [githubarchive:month.201504]
where
  LOWER(org.login) like '%freebsd%'
group by
  org
order by
  org
;
