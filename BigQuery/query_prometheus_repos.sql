select 
  org.login as org,
repo.name as repo
from
  [githubarchive:month.201704],
  [githubarchive:month.201703],
  [githubarchive:month.201702],
  [githubarchive:month.201701],
  [githubarchive:year.2016],
  [githubarchive:year.2015]
where
  LOWER(org.login) = 'prometheus'
group by
  org, repo
order by
  org, repo
;
