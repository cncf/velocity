select
  sum(activity) as activity,
  sum(comments) as comments,
  sum(prs) as prs,
  sum(commits) as commits,
  sum(issues) as issues,
  EXACT_COUNT_DISTINCT(author_email) as authors_alt2,
  GROUP_CONCAT(STRING(author_name)) AS authors_alt1,
  GROUP_CONCAT(STRING(author_email)) AS authors
from (
select
  count(*) as activity,
  SUM(IF(type = 'IssueCommentEvent', 1, 0)) as comments,
  SUM(IF(type = 'PullRequestEvent', 1, 0)) as prs,
  SUM(IF(type = 'PushEvent', 1, 0)) as commits,
  SUM(IF(type = 'IssuesEvent', 1, 0)) as issues,
  IFNULL(REPLACE(JSON_EXTRACT(payload, '$.commits[0].author.email'), '"', ''), '(null)') as author_email,
  IFNULL(REPLACE(JSON_EXTRACT(payload, '$.commits[0].author.name'), '"', ''), '(null)') as author_name
from  (select * from    TABLE_DATE_RANGE([githubarchive:day.],TIMESTAMP('2016-11-01'),TIMESTAMP('2017-11-01'))  )
where
  (    org.login in ('cloudfoundry', 'cloudfoundry-attic', 'cloudfoundry-community', 'cloudfoundry-incubator', 'cloudfoundry-samples'))
  and type in ('IssueCommentEvent', 'PullRequestEvent', 'PushEvent', 'IssuesEvent')
  and actor.login not like '%bot%'  
  AND LOWER(actor.login) not like '%cf-%'
  AND LOWER(actor.login) not in ('pubtools-doc-helper', 'routing-ci', 'runtime-ci', 'cf-buildpacks-eng')
group by author_name, author_email
)
group by author_name
order by activity desc
limit 10000
;
