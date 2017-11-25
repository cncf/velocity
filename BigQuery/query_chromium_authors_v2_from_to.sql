select
  count(*) as activity,
  SUM(IF(type = 'IssueCommentEvent', 1, 0)) as comments,
  SUM(IF(type = 'PullRequestEvent', 1, 0)) as prs,
  SUM(IF(type = 'PushEvent', 1, 0)) as commits,
  SUM(IF(type = 'IssuesEvent', 1, 0)) as issues,
  IFNULL(REPLACE(JSON_EXTRACT(payload, '$.commits[0].author.name'), '"', ''), '(null)') as author_name
from  (select * from    TABLE_DATE_RANGE([githubarchive:day.],TIMESTAMP('2016-11-01'),TIMESTAMP('2017-10-31'))  )
where
  (org.login in ('ChromeDevTools','ChromeExtensionStore','GoogleChrome','MobileChromeApps','chrome-enhanced-history','ChromiumWebApps','chromium','chromiumify'))
  and type in ('IssueCommentEvent', 'PullRequestEvent', 'PushEvent', 'IssuesEvent')
  and actor.login not like '%bot%'
  AND actor.login NOT IN ('codecov-io', 'coveralls', 'Travis CI')
group by author_name
order by activity desc
limit 10000
;
