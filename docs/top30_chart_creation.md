[<- Back to the cncf/velocity README.md file](../README.md)

[Guide to non-github project processing](docs/non_github_repositories.md)

[Other useful notes](docs/other_notes.md)

## Guide to the Top 30 projects chart creation

`analysis.rb` can be used to create data for a Cloud Native Computing Foundation projects bubble chart such as this one
![sample chart](./top30_chart_example.png?raw=true "CNCF projects")

The chart itself can be generated in a [google sheet](https://docs.google.com/spreadsheets/d/14P8bML_jqutv1zzYy588rLSX-GjLy0Cc5aSCBY05CGE/)
or as a stand-alone [html page](../charts/top_30_201611_201710.html). Details on usage of google chart api are [here](https://developers.google.com/chart/interactive/docs/gallery/bubblechart). <br />The first option is a copy/paste of resulting data where the second presents more control to the look of the chart. Refer [here](other_notes.md#bubble-chart-generator) to cteate the html automatically.

### Chart data

Verify [this query](../BigQuery/query_201611_201710_unlimited.sql) for proper date range. If a project does not have a GitHub repo or only lists a mirror, skip it for now but later add manually.

Run the query on https://bigquery.cloud.google.com/queries/

Copy the results to a file like 'data/unlimited_output_201611_201710.csv'

Run `analysis.rb` with
```
ruby analysis.rb data/unlimited_output_201611_201710.csv projects/projects_cncf_201611_201710.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_unlimited.csv
```

Make a copy of the [google doc](https://docs.google.com/spreadsheets/d/14P8bML_jqutv1zzYy588rLSX-GjLy0Cc5aSCBY05CGE/)

Put results of the analysis into a file and import the data in the 'Data' sheet in cell H1. <br />
File -> Import -> Upload -> in the Import location section, select the radio button called 'Replace data at selected cell', click Import data

Select the Chart tab, it will be updated automatically


To generate all data for the Top 30 chart: https://docs.google.com/spreadsheets/d/1hD-hXlVT60AGhGVifNn7nNo9oVMKnIoQ2kBNmx-YY8M/edit?usp=sharing

- Fetch all necessary data using BigQuery or use data already fetched present in this repo.
- If fetched new BigQuery data then re-run the special projects BigQuery analysis scripts: ./shells/: run_apache.sh, run_chrome_chromium.sh, run_cncf.sh, run_openstack.sh
- To just regenerate all other data: run `./shells/unlimited_both.sh`
- See per project ranks statistics: `reports/cncf_projects_ranks.txt`
- Get final output file `projects/unlimited.csv` and import it on the A50 cell in `https://docs.google.com/spreadsheets/d/1hD-hXlVT60AGhGVifNn7nNo9oVMKnIoQ2kBNmx-YY8M/edit?usp=sharing` chart


### Example - generate chart for a new date range
We already have `shells/unlimited_both.sh` that generates our chart for 2016-05-01 to 2017-05-01. We want to generate the chart for a new date range: 2016-06-01 to 2017-06-01.
This is a step by step tutorial on how to do it.
- Copy `shells/unlimited_both.sh` to `shells/unlimited_20160601-20170601.sh`
- Keep `shells/unlimited_20160601-20170601.sh` opened in some other terminal window `vi shells/unlimited_20160601-20170601.sh` and we need to update all steps
- First we need unlimited BigQuery output for a new date range:
```
echo "Restoring BigQuery output"
cp data/unlimited_output_201605_201704.csv data/unlimited.csv
```
- We need the `data/unlimited_output_201606_201705.csv` file. To generate this one, we need to run BigQuery for the new date range.
- Open the sql file that generated the current range's data: `vi BigQuery/query_201605_201704_unlimited.sql`
- Save as `BigQuery/query_201606_201705_unlimited.sql` after changing the date ranges in SQL.
- Copy to clipboard `pbcopy < BigQuery/query_201606_201705_unlimited.sql` and run in Google BigQuery: `https://bigquery.cloud.google.com/queries/<<your_google_project_name>>`
- Save result to a table `<<your_google_user_name>>:unlimited_201606_201705`, it takes about 1TB and costs about $5 "Save as table"
- Open this table `<<your_google_user_name>>:unlimited_201606_201705` and click "Export Table" to export it to google storage as: `gs://<<your_google_user_name>>/unlimited_201606_201705.csv` (You may click "View files" to see files in your gstorage)
- Go to google storage and download `<<your_google_user_name>>/unlimited_201606_201705.csv` and put it where `shells/unlimited_20160601-20170601.sh` expects it (update the file name to `data/unlimited_output_201606_201705.csv`): 
```
echo "Restoring BigQuery output"
cp data/unlimited_output_201606_201705.csv data/unlimited.csv
```
- So we have main data (step 1) ready for the new chart Now we need to get data for all non-standard projects. You can try our analysis tool without any special projects by running:
`ruby analysis.rb data/unlimited.csv projects/unlimited_both.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv`
- There can be some new projects that are unknown, ranks can chage during this step, so there can be manual changes needed to mappings in `map/` directory: `hints.csv`, `defmaps.csv` and `urls.csv`. Possibly also in `skip.csv` (if there are new projects that should be skipped)
- This is what came out on the 1st run:
```
Project #23 (org, 457) skillcrush (skillcrush) (skillcrush-104) have no URL defined
Project #45 (org, 366) pivotal-cf (pivotal-cf) (...) have no URL defined
Project #50 (org, 353) Automattic (Automattic) (...) have no URL defined
```
- Let's see which top authors projects for those non-found projects are: `rauth[res[res.map { |i| i[0] }.index('Automattic')][0]]`
- Then we must add entries for few top ones in `map/hints.csv` say with >= 20 authors:
```
Automattic/amp-wp,31
Automattic/wp-super-cache,29
Automattic/simplenote-electron,22
Automattic/happychat-service,21
Automattic/kue,20
```
We need to examine each one in `github.com`, like for the 1st project: `github.com/Automattic/amp-wp`. We see that this is a WordPress plugin, so it belnogs to the wWrdpress/WP Calypso project:
`grep -HIn "wordpress" map/*.csv`
`grep -HIn "WP Calypso" map/*.csv`
We see that we have WP Calypso defined in the hints file:
```
map/hints.csv:23:Automattic/WP-Job-Manager,WP Calypso
map/hints.csv:24:Automattic/facebook-instant-articles-wp,WP Calypso
map/hints.csv:26:Automattic/sensei,WP Calypso
map/hints.csv:29:Automattic/wp-calypso,WP Calypso
map/hints.csv:30:Automattic/wp-e2e-tests,WP Calypso
map/urls.csv:438:WP Calypso,developer.wordpress.com/calypso
```
Just add a new repo mapping row for this project (`map/hints.csv`): `Automattic/amp-wp,WP Calypso`
Do the same for other projects/repos. Re-run the analysis tool untill all is fine.
- For example, after defining some new projects we see "EPFL-SV-cpp-projects" in the top 50. This is an educational org that should be skipped. Add it to `map/skip.csv` for skipping row: `EPFL-SV-cpp-projects,,`
- Once You have all URL's defined, added new mapping, you may see a preview of the Top projects on while stopped in `binding.pry`, by typing `all`. Now we need to go back to `shells/unlimited_20160601-20170601.sh` and regenerate all non standard data (for projects not on github or requiring special queries on github - for example because of having 0 activity, comments, commits, issues, prs or authors)

- Now Linux case: we need to change this line `ruby add_linux.rb data/unlimited.csv data/data_linux.csv 2016-05-01 2017-05-01` into `ruby add_linux.rb data/unlimited.csv data/data_linux.csv 2016-06-01 2017-06-01` and run it
- A message will be shown: `Data range not found in data/data_linux.csv: 2016-06-01 - 2017-06-01`. That means you need to add a new data range for Linux in file: `data/data_linux.csv`
- Data for linux is here `https://docs.google.com/spreadsheets/d/1CsdreHox8ev89WoP6LjcryroKDOH2gQipMC9oS95Zhc/edit?usp=sharing` but it doesn have May 2017 (finished yesterday), so we need last month's data.
- Go to: `https://lkml.org/lkml/2017` and copy May 2017 into linked google spreadsheet: (22110).
- Add a row for May 2017 to `data/data_linux.csv`: `torvalds,torvalds/linux,2017-05-01,2017-06-01,0,0,0,0,22110` - You will see that now we only have the "emails" column. Other columns must be feteched from the linux kernel repo using the `cncf/gitdm` analysis:
- You can also sum up the issues from the sheet to get 2016-06-01 - 2017-06-01: (254893): `torvalds,torvalds/linux,2016-06-01,2017-06-01,0,0,0,0,254893`
- Now `cncf/gitdm` on linux kernel repo: `cd ~/dev/linux && git checkout master && git reset --hard && git pull`. An alternative to it (if you don't have the linux repo cloned) is: `cd ~/dev/`, `git clone https://github.com/torvalds/linux.git`.
- Go to `cncf/gitdm`: `cd ~/dev/cncf/gitdm`, run: `./linux_range.sh 2017-05-01 2017-06-01`
- While on `cncf/gitdm`, see: `vim linux_stats/range_2017-05-01_2017-06-01.txt`:
```
Processed 1219 csets from 424 developers
34 employers found
A total of 24970 lines added, 14469 removed (delta 10501)
```
- You have values for `changesets,additions,removals,authors` here, update `cncf/velocity/data/data_linux.csv` accordingly.
- Do the same for `./linux_range.sh 2016-06-01 2017-06-01` and `linux_stats/range_2016-06-01_2017-06-01.txt`, Results:
```
Processed 64482 csets from 3803 developers
91 employers found
A total of 3790914 lines added, 1522111 removed (delta 2268803)
```
- Final linux rows (one for May 2017, another for last year including May 2017) are:
```
torvalds,torvalds/linux,2017-05-01,2017-06-01,1219,24970,14469,424,22110
torvalds,torvalds/linux,2016-06-01,2017-06-01,64482,3790914,1522111,3803,254893
```

- GitLab case: Their repo is: `https://gitlab.com/gitlab-org/gitlab-ce/`, clone it via: `git clone https://gitlab.com/gitlab-org/gitlab-ce.git` in `~/dev/` directory.
- Their repo hosted by GitHub is: `https://github.com/gitlabhq/gitlabhq`, clone it via `git clone https://gitlab.com/gitlab-org/gitlab-ce.git` in `~/dev/` directory.
- Go to `cncf/gitdm` and run GitLab repo analysis: `./repo_in_range.sh ~/dev/gitlab-ce/ gitlab 2016-06-01 2017-06-01`
- Results are output to `other_repos/gitlab_2016-06-01_2017-06-01.txt`:
```
Processed 16574 csets from 513 developers
15 employers found
A total of 926818 lines added, 548205 removed (delta 378613)
```
- Their bug tracker is `https://gitlab.com/gitlab-org/gitlab-ce/issues`, just count issues in the given date range. Sort by "Last created" and count issues in given range:
There are 732 pages of issues (20 per page) = 14640 issues (`https://gitlab.com/gitlab-org/gitlab-ce/issues?page=732&scope=all&sort=created_desc&state=all`)
- To count Merge Requests (PRs): `https://gitlab.com/gitlab-org/gitlab-ce/merge_requests?scope=all&state=all`
Merge Requests: 371,5 pages * 20 = 7430
- To count authors run in gitlab-ce directory: `git log --since "2016-06-01" --until "2017-06-01" --pretty=format:"%aE" | sort | uniq | wc -l` --> 575
- To count authors run in gitlab-ce directory: `git log --since "2016-05-01" --until "2017-05-01" --pretty=format:"%aE" | sort | uniq | wc -l` --> 589

- Cloud Foundry case:
- Copy: `BigQuery/query_cloudfoundry_201605_201704.sql` to `BigQuery/query_cloudfoundry_201606_201705.sql` and update conditions. Then run query in the BigQuery console (see details at the beginning of example)
- Finally, you will have `data/data_cloudfoundry_201606_201705.csv` (run query, save results to table, export table to gstorage, download csv from gstorage).
- Update (and eventually manually run) the CF case (in `shells/unlimited_20160601-20170701.sh`): `ruby merger.rb data/unlimited.csv data/data_cloudfoundry_201606_201705.csv force`

- CNCF Projects case
- We have a line in `ruby merger.rb data/unlimited.csv data/data_cncf_projects.csv` which needs to be changed to `ruby merger.rb data/unlimited.csv data/data_cncf_projects_201606_201705.csv`
- Copy: `cp BigQuery/query_cncf_projects.sql BigQuery/query_cncf_projects_201606_201705.sql`, update conditions: `BigQuery/query_cncf_projects_201606_201705.sql`
- Run on BigQuery and do the same as in the CF case. The final output file will be: `data/data_cncf_projects_201606_201705.csv`
- Final line should be (try it): `ruby merger.rb data/unlimited.csv data/data_cncf_projects_201606_201705.csv`

- WebKit case
- Change merger line to `ruby merger.rb data/unlimited.csv data/webkit_201606_201705.csv`
- WebKit has no usable data on GitHub, so running BigQuery is not needed, we no longer need those lines for WebKit (we will just update `data/webkit_201606_201705.csv` file), remove them from current shell `shells/unlimited_20160601-20170601.sh`:
```
echo "Updating WebKit project using gitdm and other"
ruby update_projects.rb projects/unlimited_both.csv data/data_webkit_gitdm_and_others.csv -1
```
- Now we need to generate the values for `data/webkit_201606_201705.csv` file:
- Issues:
Go to: https://webkit.org/reporting-bugs/
Search all bugs in webkit, order by modified desc - will be truncated to 10,000.
https://bugs.webkit.org/buglist.cgi?bug_status=UNCONFIRMED&bug_status=NEW&bug_status=ASSIGNED&bug_status=REOPENED&bug_status=RESOLVED&bug_status=VERIFIED&bug_status=CLOSED&limit=0&order=changeddate%20DESC%2Cbug_status%2Cpriority%2Cassigned_to%2Cbug_id&product=WebKit&query_format=advanced&resolution=---&resolution=FIXED&resolution=INVALID&resolution=WONTFIX&resolution=LATER&resolution=REMIND&resolution=DUPLICATE&resolution=WORKSFORME&resolution=MOVED&resolution=CONFIGURATION%20CHANGED
2016-12-13 --> 2017-06-01 = 9988 issues:
ruby> Date.parse('2017-06-01') - Date.parse('2016-12-13') => (170/1), (9988.0 * 365.0/170.0) --> 21444 issues
See how many days makes 10k, and estimate for 365 days (1 year): gives 22k bugs/issues
- Commits, Authors:
`cd ~dev/ && git clone git://git.webkit.org/WebKit.git WebKit`
- Some git one liner stats:
All authors & commits
`git log --pretty=format:"%aE" | sort | uniq | wc -l` --> 648
`git log --pretty=format:"%H" | sort | uniq | wc -l` --> 189693
And for our date period:
`git log --since "2016-06-01" --until "2017-06-01" --pretty=format:"%aE" | sort | uniq | wc -l` --> 125
`git log --since "2016-06-01" --until "2017-06-01" --pretty=format:"%H" | sort | uniq | wc -l` --> 13348
- Now use cncf/gitdm to analyse commits, authors: from `cncf/gitdm` directory run: `./repo_in_range.sh ~/dev/WebKit/ WebKit 2016-06-01 2017-06-01`
- See output: `vim other_repos/WebKit_2016-06-01_2017-06-01.txt`:
```
Processed 13337 csets from 125 developers
6 employers found
A total of 11838610 lines added, 3105609 removed (delta 8733001)
```
- So we have authors=125, commits=13348
- Now we need to estimate the remaining: activity, comments, prs:
- A good idea is to get it from ALL projects summaries (we have value for ALL keys summed-up in all projects from analysis.rb), this is automatically saved by `analysis.rb` to `reports/sumall.csv` file.
- The record from last `analysis.rb` run is: `{"activity"=>30714776, "comments"=>12766215, "prs"=>3311370, "commits"=>11687914, "issues"=>3104377}`
- Now average PRs/issues: sumall['prs'].to_f / sumall['issues'].to_f = 1.07 which gives PRs = 1.1 * 21444 = 23600
- Comments would be 2 * commits = 26000
- Activity = sum of all others (comments, commits, issues, prs)

- OpenStack case:
- Change line `ruby merger.rb data/unlimited.csv data/data_openstack_201605_201704.csv` to `ruby merger.rb data/unlimited.csv data/data_openstack_201606_201705.csv`
- To get `data/data_openstack_201606_201705.csv` file from BigQuery do:
- Copy `cp BigQuery/query_openstack_projects.sql BigQuery/query_openstack_projects_201606_201705.sql` and update date range condition in `BigQuery/query_openstack_projects_201606_201705.sql`
- Copy to clipboard `pbcopy < BigQuery/query_openstack_projects_201606_201705.sql` and run BigQuery, Save as Table, export to gstorage, and save the results as `data/data_openstack_201606_201705.csv`
- Run `ruby merger.rb data/unlimited.csv data/data_openstack_201606_201705.csv` for a test
- Now need to update data to get file `data/data_openstack_bugs_201606_201705.csv` (copy file from `data/data_openstack_bugs.csv`)
- Use thier launchpad to get issues info:
https://wiki.openstack.org/wiki/Bugs
Specifically go to: `When you find a bug, you should file it against the proper OpenStack project using the corresponding link`
Click for example "Report a bug in Nova"
https://bugs.launchpad.net/nova/, go to Advanced, select all possible issues, click "Age" sort desc, and then manually count issues in the given date range
Once you have one correct URL, like:
https://bugs.launchpad.net/keystone/+bugs?field.searchtext=&search=Search&field.status%3Alist=NEW&field.status%3Alist=OPINION&field.status%3Alist=INVALID&field.status%3Alist=WONTFIX&field.status%3Alist=EXPIRED&field.status%3Alist=CONFIRMED&field.status%3Alist=TRIAGED&field.status%3Alist=INPROGRESS&field.status%3Alist=FIXCOMMITTED&field.status%3Alist=FIXRELEASED&field.status%3Alist=INCOMPLETE_WITH_RESPONSE&field.status%3Alist=INCOMPLETE_WITHOUT_RESPONSE&assignee_option=any&field.assignee=&field.bug_reporter=&field.bug_commenter=&field.subscriber=&field.structural_subscriber=&field.tag=&field.tags_combinator=ANY&field.has_cve.used=&field.omit_dupes.used=&field.omit_dupes=on&field.affects_me.used=&field.has_patch.used=&field.has_branches.used=&field.has_branches=on&field.has_no_branches.used=&field.has_no_branches=on&field.has_blueprints.used=&field.has_blueprints=on&field.has_no_blueprints.used=&field.has_no_blueprints=on&orderby=-datecreated&memo=350&start=75
You will replace "keystone" with projects names like: nova, glance, swift, horizon etc.
After each replace, click "Age" to sort the created desc. Note how many issues discard from first page (as too new) or next pages.
Then manipulate the "memo" parameter (end of URL) to get a starting value. And choose such value when start date is within. Count issues using memo + #isse which is out - numbe rof issues from 1st (or more) pages which come after.
Estimate for all 12 OpenStack projects.

Example for Murano:
https://bugs.launchpad.net/murano/+bugs?field.searchtext=&search=Search&field.status%3Alist=NEW&field.status%3Alist=OPINION&field.status%3Alist=INVALID&field.status%3Alist=WONTFIX&field.status%3Alist=EXPIRED&field.status%3Alist=CONFIRMED&field.status%3Alist=TRIAGED&field.status%3Alist=INPROGRESS&field.status%3Alist=FIXCOMMITTED&field.status%3Alist=FIXRELEASED&field.status%3Alist=INCOMPLETE_WITH_RESPONSE&field.status%3Alist=INCOMPLETE_WITHOUT_RESPONSE&assignee_option=any&field.assignee=&field.bug_reporter=&field.bug_commenter=&field.subscriber=&field.structural_subscriber=&field.tag=&field.tags_combinator=ANY&field.has_cve.used=&field.omit_dupes.used=&field.omit_dupes=on&field.affects_me.used=&field.has_patch.used=&field.has_branches.used=&field.has_branches=on&field.has_no_branches.used=&field.has_no_branches=on&field.has_blueprints.used=&field.has_blueprints=on&field.has_no_blueprints.used=&field.has_no_blueprints=on&orderby=-datecreated&memo=425&start=350&direction=backwards
- The final line should be `ruby update_projects.rb projects/unlimited_both.csv data/data_openstack_bugs_201606_201705.csv -1`

- Apache case:
- Exactly the same BigQuery steps as in the OpenStack example,. The final line should be `ruby merger.rb data/unlimited.csv data/data_apache_201606_201705.csv`
- `cp BigQuery/query_apache_projects.sql BigQuery/query_apache_projects_201606_201705.sql`, update conditions, run BigQ, download results to `data/data_apache_201606_201705.csv`
- Run `ruby merger.rb data/unlimited.csv data/data_apache_201606_201705.csv`
- Now we need more data for Apache from their jira, first copy file from previous data range `cp data/data_apache_jira.csv data/data_apache_jira_201606_201705.csv`
- Now go to their jira: issues.apache.org/jira/browse, you may set conditions to find issues, like this:
```
project not in (FLINK, MESOS, SPARK, KAFKA, CAMEL, FLINK, CLOUDSTACK, BEAM, ZEPPELIN, CASSANDRA, HIVE, HBASE, HADOOP, IGNITE, NIFI, AMBARI, STORM, "Traffic Server", "Lucene - Core", Solr, CarbonData, GEODE, "Apache Trafodion", Thrift, Kylin) AND created >= 2016-05-01 AND created <= 2017-05-01
```
Example URL: `https://issues.apache.org/jira/browse/ZOOKEEPER-2769?jql=project%20not%20in%20(FLINK%2C%20MESOS%2C%20SPARK%2C%20KAFKA%2C%20CAMEL%2C%20FLINK%2C%20CLOUDSTACK%2C%20BEAM%2C%20ZEPPELIN%2C%20CASSANDRA%2C%20HIVE%2C%20HBASE%2C%20HADOOP%2C%20IGNITE%2C%20NIFI%2C%20AMBARI%2C%20STORM%2C%20%22Traffic%20Server%22%2C%20%22Lucene%20-%20Core%22%2C%20Solr%2C%20CarbonData%2C%20GEODE%2C%20%22Apache%20Trafodion%22%2C%20Thrift%2C%20Kylin)%20AND%20created%20%3E%3D%202016-05-01%20AND%20created%20%3C%3D%202017-05-01`
We need: Mesos, Spark, Kafka, Camel, Flink (above query is for other projects, these will not be included)
Query for Mesos in our data range: `project in (Mesos) AND created >= 2016-06-01 AND created <= 2017-06-01` --> 2055
Do this for all projects.
- Final line for Apache should be: `ruby update_projects.rb projects/unlimited_both.csv data/data_apache_jira_201606_201705.csv -1`

- Chromium case
- Beginning (BigQuery part) exactly the same as Apache or OpenStack (just replace with word chromium): `ruby merger.rb data/unlimited.csv data/data_chromium_201606_201705.csv`
- Now the manual part - copy `data/data_chromium_bugtracker.csv` to `data/data_chromium_bugtracker_201606_201705.csv` (we need to generate this file)
- Get Issues from their bug tracker: https://bugs.chromium.org/p/chromium/issues/list?can=1&q=opened%3E2016%2F7%2F25&colspec=ID+Pri+M+Stars+ReleaseBlock+Component+Status+Owner+Summary+OS+Modified&x=m&y=releaseblock&cells=ids
All issues + opened>2016/7/19 gives: 63565 (for 2016/7/18 gives 63822+ which means a non exact number) we will extrapolate from here.
All issues + opened>2017/6/1 gives 325, so we have: 63565 - 325 = 63240 issues in 2016-07-19 - 2017-06-01
irb> require 'date'; Date.parse('2017-06-01') - Date.parse('2016-07-19') --> 317
irb> Date.parse('2017-06-01') - Date.parse('2016-06-01') --> 365
irb> 63240.0 * (365.0 / 317.0) --> 72815 
Now add chromedriver too:
All issues, opened>2017/6/1 --> 1
All issues, opened>2016/6/1 --> 430
So there are 429 chromedriver issues and the total is: 429 + 72815 = 73244
- Now chromium commits analysis which is quite complex
- Their sources (all projects) are here: https://chromium.googlesource.com
- Clone `chromium/src` in `~/dev/src/`: `git clone https://chromium.googlesource.com/chromium/src`
- Commits: `git log --since "2016-06-01" --until "2017-06-01" --pretty=format:"%H" | sort | uniq | wc -l` gives 79144 (but this is only FYI, this is way too many, there are bot commits here)
- Authors: `git log --since "2016-06-01" --until "2017-06-01" --pretty=format:"%aE" | sort | uniq | wc -l` gives 1697
To analyze those commits (also exclude merge and robot commits):
Run while in chromium/src repository:
`git log --since "2016-05-01" --until "2017-05-01" --pretty=format:"%aE~~~~%aN~~~~%H~~~~%s" | sort | uniq > chromium_commits_201606_201705.csv`
Then remove special CSV characters with VI commands: `:%s/"//g`, `:%s/,//g`
Then add CSV header manually "email,name,hash,subject" and move it to: `cncf/velocity`:`data/data_chromium_commits_201606_201705.csv`: `mv chromium_commits_201606_201705.csv ~/dev/cncf/velocity/data/data_chromium_commits_201606_201705.csv`
Finally replace '~~~~' with ',' to create correct CSV: `:%s/\~\~\~\~/,/g`
Then run `ruby commits_analysis.rb data/data_chromium_commits_201606_201705.csv map/skip_commits.csv`
Eventually/optionally add new rules to skip commits to `map/skip_commits.csv`
Tool will say something like this: "After filtering: authors: 1637, commits: 67180", update `data/data_chromium_bugtracker_201606_201705.csv` accordingly.
- Final line should be `ruby update_projects.rb projects/unlimited_both.csv data/data_chromium_bugtracker_201606_201705.csv -1`

- openSUSE case
- BigQuery part exactly the same as Apache or OpenStack (just replace with word opensuse): `ruby merger.rb data/unlimited.csv data/data_opensuse_201606_201705.csv`

- AGL (automotive Grade Linux) case:
- Go to: https://wiki.automotivelinux.org/agl-distro/source-code and get source code somewhere:
- `mkdir agl; cd agl`
- `curl https://storage.googleapis.com/git-repo-downloads/repo > repo; chmod +x ./repo`
- `./repo init -u https://gerrit.automotivelinux.org/gerrit/AGL/AGL-repo; ./repo init`
- Now You need to use script `agl/run_multirepo.sh` that uses `cncf/gitdm` to generate GitHub statistics.
- There will be `agl.txt` file generated, something like this:
```
Processed 67124 csets from 1155 developers
52 employers found
A total of 13431516 lines added, 12197416 removed, 24809064 changed (delta 1234100)
```
- You can get number of authors: 1155 and commits 67124 (this is for all time)
- To get data for some specific data range: `cd agl; DTFROM="2016-10-01" DTTO="2017-10-01" ./run_multirepo_range.sh` ==> `agl.txt`.
```
Processed 7152 csets from 365 developers
```
- 7152 commits and 365 authors.
- To get number of Issues, search Jira: `https://jira.automotivelinux.org/browse/SPEC-923?jql=created%20%3E%3D%202016-10-01%20AND%20created%20%3C%3D%202017-10-01`
- It says 665 issues in a given date range

- LibreOffice case
- Beginning (BigQuery part) exactly the same as Apache or OpenStack (just replace with word libreoffice): `ruby merger.rb data/unlimited.csv data/data_libreoffice_201606_201705.csv`
- Now git repo analysis:, first copy `cp data/data_libreoffice_git.csv data/data_libreoffice_git_201606_201705.csv` and we will update the `data/data_libreoffice_git_201606_201705.csv` file
- Get source code: https://www.libreoffice.org/about-us/source-code/, for example: `git clone git://anongit.freedesktop.org/libreoffice/core` in `~/dev/`
- Analyse this repo as described in: `res/libreoffice_git_repo.txt`, to see that it generates lower number than those from BigQuery output (so we can skip this step)
- Commits: `git log --since "2016-05-01" --until "2017-05-01" --pretty=format:"%H" | sort | uniq | wc -l`
- Authors: `git log --since "2016-05-01" --until "2017-05-01" --pretty=format:"%aE" | sort | uniq | wc -l`
- Put results in: `data/data_libreoffice_git_201606_201705.csv` (authors, commits), values will probably be skipped by the updater tool (they are lower than current values gathered so far)
- Issues:
Issue listing is here: https://bugs.freedesktop.org/buglist.cgi?product=LibreOffice&query_format=specific&order=bug_id&limit=0
Create account, change columns to "Opened" and "ID" generaly no more needed. (ID is a link). Sprt by Opened desc and try to see all results. (You can hit nginx gateway timeout).
This URL succeeded for me: https://bugs.documentfoundation.org/buglist.cgi?bug_status=UNCONFIRMED&bug_status=NEW&bug_status=ASSIGNED&bug_status=REOPENED&bug_status=RESOLVED&bug_status=VERIFIED&bug_status=CLOSED&bug_status=NEEDINFO&columnlist=opendate&component=Android%20Viewer&component=Base&component=BASIC&component=Calc&component=Chart&component=ci-infra&component=contrib&component=deletionrequest&component=Documentation&component=Draw&component=Extensions&component=filters%20and%20storage&component=Formula%20Editor&component=framework&component=graphics%20stack&component=Impress&component=Installation&component=LibreOffice&component=Linguistic&component=Localization&component=Printing%20and%20PDF%20export&component=sdk&component=UI&component=ux-advise&component=Writer&component=Writer%20Web&component=WWW&limit=0&list_id=703831&order=opendate%20DESC%2Cchangeddate%2Cbug_id%20DESC&product=LibreOffice&query_format=advanced&resolution=---&resolution=FIXED&resolution=INVALID&resolution=WONTFIX&resolution=DUPLICATE&resolution=WORKSFORME&resolution=MOVED&resolution=NOTABUG&resolution=NOTOURBUG&resolution=INSUFFICIENTDATA
Download as csv to `data/data_libreoffice_bugs.csv`, and then count issues with given date range "2016-06-01" --> "2017-06-01" with `ruby count_issues.rb data/data_libreoffice_bugs.csv Opened '2016-06-01 00:00:00' '2017-06-01 00:00:00'`
```
ruby count_issues.rb data/data_libreoffice_bugs.csv Opened 2016-06-01 2017-06-01
Counting issues in 'data/data_libreoffice_bugs.csv', issue date column is 'Opened', range: 2016-06-01T00:00:00+00:00 - 2017-06-01T00:00:00+00:00
Found 7223 matching issues.
```
Update `data/data_libreoffice_git_201606_201705.csv` accordingly.
- Final line should be: `ruby update_projects.rb projects/unlimited_both.csv data/data_libreoffice_git_201606_201705.csv -1`

- Now let's examine a new case: FreeBSD:
- Use BigQuery/org_finder.sql (with condition '%freebsd%' to find FreeBSD orgs). Check all of them on GitHub and create final BigQuery:
- `cp BigQuery/query_apache_projects.sql BigQuery/query_freebsd_projects.sql` and update conditions, run query, download results, put them in `data/data_freebsd_201606_201705.csv` (save as table, export to gstorage, download csv)
- Now define FreeBSD project the same way as in BigQuery: put orgs in `map/defmaps.csv`, put URL in `map/urls.csv`, put orgs as exceptions in `map/ranges.csv` and `map/ranges_sane.csv` (because some values can be 0s due to custom BigQuery)
- Add FreeBSD processing to shells/unlimited:
```
echo "Adding/Updating FreeBSD Projects"
ruby merger.rb data/unlimited.csv data/data_freebsd_201606_201705.csv
```
- Go to `~/dev/freebsd` and clone 3 SVN repos:
```
svn checkout https://svn.freebsd.org/base/head base
svn checkout https://svn.freebsd.org/doc/head doc
svn checkout https://svn.freebsd.org/ports/head ports
```
- Use `cncf/gitdm/freebsd_svn.sh` script to analyse FreeBSD SVN repos:
```
Revisions:    35927
Authors:      335
```
- Now rerun `shells/unlimited_201606_201705.sh` and see FreeBSD's rank

- Run final updated script: `shells/unlimited_20160601-20170601.sh` to get final results.

- Finally `./projects/unlimited.csv` is generated. You need to import it in final Google chart by doing:
- Select the cell A50. Use File --> Import, then "Upload" tab, "Select a file from your computer", choose `./projects/unlimited.csv`
- Then "Import action" --> "replace data starting at selected call", click Import.
- Voila!
Final version will live here: https://docs.google.com/spreadsheets/d/1a2VdKfAI1g9ZyWL09TnJ-snOpi4BC9kaEVmB7IufY7g/edit?usp=sharing

### Results:

NOTE: for viewing using those motion charts You'll need Adobe Flash enabled when clicking links. It works (tested) on Chrome and Safari with Adobe Flash installed and enabled.

For data from files.csv (data/data_YYYYMM.csv), 201601 --> 201703 (15 months)
Chart with cumulative data (each month is sum of this month and previous months) is here:
https://docs.google.com/spreadsheets/d/11qfS97WRwFqNnArRmpQzCZG_omvZRj_y-MNo5oWeULs/edit?usp=sharing
Chart with monthly data (that looks wrong IMHO due to google motion chart data interpolation between months) is here: 
https://docs.google.com/spreadsheets/d/1ZgdIuMxxcyt8fo7xI1rMeFNNx9wx0AxS-2a58NlHtGc/edit?usp=sharing

I suggest playing around with the 1st chart (cumulative sum):
It is not able to remember settings so once you click on "Chart1" scheet I suggest:
- Change axis-x and axis-y from Lin (linerar) to Log (logarithmics)
- You can choose what column should be used for color: I suggest activity (this is default and shows which project was most active) or choose unique color (You can select from commits, prs+issues, size) (size is square root of number of authors)
- Change playback speed (control next to play) to slowest
- Select inerested projects from Legend (like Kubernetes for example or Kubernetes vs dotnet etc) and check "trails"
- You can also change what x and y axisis use as data, defaults are: x=commits, y=pr+issues, and change scale type lin/log
- You can also change which column is used for bubble size (default is "size" which means square root of number of authors), note that the number of authors = max from all months (distinct authors that contributed to activity), this is obviously different from set of distinct authors activity in the entire 15 months range

On the top/right just above the Color drop down you will see additional two chart types:
- Bar chart - this can be very useful
- Choose li or log y-axis scale, then select Kubernetes from Legend and then choose any of y-axis possible values (activity, commits, PRs+issues, Size) and click play to see how Kubernetes overtakes multiple projects during our period.
Finally there is also a linear chart, take a look at it as well.