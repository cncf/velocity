[<- Back to the cncf/velocity README.md file](../README.md)

[Guide to non-github project processing](non_github_repositories.md)

[Other useful notes](other_notes.md)

## Guide to the Linux Foundation projects chart creation

`analysis.rb` can be used to create data for a Cloud Native Computing Foundation projects bubble chart such as this one
![sample chart](./linuxfoundation_chart_example.png?raw=true "CNCF projects")

The chart itself can be generated in a [google sheet](https://docs.google.com/spreadsheets/d/1_DIvQpaPRecRONWeTh5pp3WOgbGcsY4JOPMBisizJqg/)
or as a stand-alone [html page](../charts/LF_bubble_chart.html). Details on usage of google chart api are [here](https://developers.google.com/chart/interactive/docs/gallery/bubblechart). The first option is a copy/paste of resulting data whereas the second presents more control to the look of the chart. Refer to the [Bubble Chart Generator](other_notes.md#bubble-chart-generator) for automatic html creation.

### Chart data
Go to this [CNCF page](https://www.linuxfoundation.org/projects/) to find a list of current projects.

For every project, find a github repo and add it to a query such as [this one](BigQuery/query_lf_projects_201611_201710.sql) appropriately - either as an org or a single repo. If a project does not have a GitHub repo or only lists a mirror, skip it for now but later add manually. Update the time range.

Run the query on https://bigquery.cloud.google.com/queries/ in the website's console. It takes about 900GB and costs about $4.50

Copy the results to a file with proper name `data/data_lf_projects_201611_201710.csv`


<b>Add Linux data</b>
Try running this from the velocity project's root folder:
`ruby add_linux.rb data/data_lf_projects_201611_201710.csv data/data_linux.csv 2016-11-01 2017-11-01`
- A message will be shown: `Data range not found in data/data_linux.csv: 2017-11-01 - 2017-11-01`. That means you need to add a new data range for Linux in file: `data/data_linux.csv`
- Go to: `https://lkml.org/lkml/2017` and sum-up monthly email counts for the time period of interest, in this case, 263996.
- Add a row for the time period in `data/data_linux.csv`: `torvalds,torvalds/linux,2016-11-01,2017-11-01,0,0,0,0,263996` - You will see that now we only have the "emails" column. Other columns must be feteched from the linux kernel repo using the `cncf/gitdm` analysis:
	- Get `cncf/gitdm` with `git clone https://github.com/cncf/gitdm.git`
	- Get or update local linux kernel repo with `cd ~/dev/linux && git checkout master && git reset --hard && git pull`. An alternative to it (if you don't have the linux repo cloned) is: `cd ~/dev/`, `git clone https://github.com/torvalds/linux.git`.
	- Go to `cncf/gitdm/`, `cd ~/dev/cncf/gitdm` and run: `./linux_range.sh 2017-11-01 2017-10-01`
	- While in `cncf/gitdm/` directory, view: `vim linux_stats/range_2017-11-01_2017-11-01.txt`:
	```
	Processed 64482 csets from 3803 developers
	91 employers found
	A total of 3790914 lines added, 1522111 removed (delta 2268803)
	```
	- You have values for `changesets,additions,removals,authors` here, update `cncf/velocity/data/data_linux.csv` accordingly.
	
	- Final linux row data for the given time period is:
	```
	torvalds,torvalds/linux,2016-06-01,2017-06-01,64482,3790914,1522111,3803,254893
	```
Run this from the velocity project's root folder again:
`ruby add_linux.rb data/data_lf_projects_201611_201710.csv data/data_linux.csv 2016-11-01 2017-11-01`

Run `analysis.rb` with
```
ruby analysis.rb data/data_lf_projects_201611_201710.csv projects/projects_lf_201611_201710.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv
```

Make a copy of the [google doc](https://docs.google.com/spreadsheets/d/1_DIvQpaPRecRONWeTh5pp3WOgbGcsY4JOPMBisizJqg/)

Put results of the analysis into a file and import the data in the 'Data' sheet in cell A66. <br />
File -> Import -> Upload -> in the Import location section, select the radio button called 'Replace data at selected cell', click Import data

Select the Chart tab, it will be updated automatically

CloudFoundry PRs and Issues counts need manual adjustment in the Data tab of the google doc.

log on to cncftest.io machine then
`sudo bash`
`sudo -u postgres psql cloudfoundry`
<b>CloudFoundry Pull Requests count</b>
```
select
count(distinct id) as number_of_prs_and_issues
from
gha_issues
where
created_at >= '2017-01-01'
and created_at < '2018-01-01'
and is_pull_request = true
and dup_user_login not in
(
'cf-buildpacks-eng',
'cm-release-bot',
'capi-bot',
'runtime-ci',
'cf-infra-bot',
'routing-ci',
'pcf-core-services-writer',
'cf-loggregator-oauth-bot',
'cf-identity',
'hcf-bot',
'cfadmins-deploykey-user',
'cf-pub-tools',
'pcf-toronto-ci-bot',
'perm-ci-bot',
'backup-restore-team-bot',
'greenhouse-ci'
)
and dup_actor_login not in
(
'cf-buildpacks-eng',
'cm-release-bot',
'capi-bot',
'runtime-ci',
'cf-infra-bot',
'routing-ci',
'pcf-core-services-writer',
'cf-loggregator-oauth-bot',
'cf-identity',
'hcf-bot',
'cfadmins-deploykey-user',
'cf-pub-tools',
'pcf-toronto-ci-bot',
'perm-ci-bot',
'backup-restore-team-bot',
'greenhouse-ci'
);
```

<b>CloudFoundry Issues count</b>
```
select
count(distinct id) as number_of_prs_and_issues
from
gha_issues
where
created_at >= '2017-01-01'
and created_at < '2018-01-01'
and is_pull_request = false
and dup_user_login not in
(
'cf-buildpacks-eng',
'cm-release-bot',
'capi-bot',
'runtime-ci',
'cf-infra-bot',
'routing-ci',
'pcf-core-services-writer',
'cf-loggregator-oauth-bot',
'cf-identity',
'hcf-bot',
'cfadmins-deploykey-user',
'cf-pub-tools',
'pcf-toronto-ci-bot',
'perm-ci-bot',
'backup-restore-team-bot',
'greenhouse-ci'
)
and dup_actor_login not in
(
'cf-buildpacks-eng',
'cm-release-bot',
'capi-bot',
'runtime-ci',
'cf-infra-bot',
'routing-ci',
'pcf-core-services-writer',
'cf-loggregator-oauth-bot',
'cf-identity',
'hcf-bot',
'cfadmins-deploykey-user',
'cf-pub-tools',
'pcf-toronto-ci-bot',
'perm-ci-bot',
'backup-restore-team-bot',
'greenhouse-ci'
);
```
