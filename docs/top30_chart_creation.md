[Back to the cncf/velocity README.md file](../README.md)

[Guide to non-github project processing](non_github_repositories.md)

[Other useful notes](other_notes.md)

## Guide to the Top 30 projects chart creation

`analysis.rb` can be used to create data for a Cloud Native Computing Foundation projects bubble chart such as this one
![sample chart](./top30_chart_example.png?raw=true "CNCF projects")

The chart itself can be generated in a [google sheet](https://docs.google.com/spreadsheets/d/14ALEBOqyLZPudxaf7gAWZPBLjDy_RMiYwaobDdBYOLs/edit?usp=sharing).

### Chart data
Before you begin, clone the cncf/gitdm repo as you will use it in addition to velocity.

#### In short
To generate all data for the [Top 30 chart](https://docs.google.com/spreadsheets/d/14ALEBOqyLZPudxaf7gAWZPBLjDy_RMiYwaobDdBYOLs/edit?usp=sharing).

- Fetch all necessary data using BigQuery or use data already fetched present in this repo.
- If fetched new BigQuery data then re-run the special projects BigQuery analysis scripts: `./shells`: `run_apache.sh`, `run_chrome_chromium.sh`, `run_cncf.sh`, `run_openstack.sh`.
- To just regenerate all other data: run `./shells/unlimited_both.sh`
- See per project ranks statistics: `reports/cncf_projects_ranks.txt`
- Get final output file `projects/unlimited.csv` and import it on the [A50 cell](https://docs.google.com/spreadsheets/d/14ALEBOqyLZPudxaf7gAWZPBLjDy_RMiYwaobDdBYOLs/edit?usp=sharing).


#### In detail
Update BigQuery [query file](BigQuery/velocity_top30.sql). If a project does not have a GitHub repo or only lists a mirror, skip it for now but later add manually.

Run the query for a year, for example: `./run_bq.sh top30 2018-07-01 2019-07-01`. It takes about 1+TB and costs about $5+.

It will generate a file for example: `data/data_top30_projects_20180701_20190701.csv`.

Run `analysis.rb` with
```
ruby analysis.rb data/data_top30_projects_20180701_20190701.csv projects/projects_top30_20180701_20190701.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_unlimited.csv
```

Make a copy of the [google doc](https://docs.google.com/spreadsheets/d/14ALEBOqyLZPudxaf7gAWZPBLjDy_RMiYwaobDdBYOLs/edit?usp=sharing).

Put results of the analysis into a file and import the data in the 'Data' sheet in cell H1.
File -> Import -> Upload -> in the Import location section, select the radio button called 'Replace data at selected cell', click Import data

Select the Chart tab, it will be updated automatically

The chart now only contains GitHub-hosted projects and for Linux Foundation purposes, is not complete. For one, it misses the Linux Kernel project. To complete the chart data, follow the next section to the end.


### Example - Top 30 chart data preparation for a new date range

Existing script `shells/unlimited_both.sh` generates our chart data for 2018-07-01 to 2019-07-01. Let's assume we want to generate the chart for a new date range: 2018-07-01 to 2019-07-01.This is a step-by-step tutorial on how to accomplish that.
- Copy `shells/unlimited_both.sh` to `shells/unlimited_20170701-20190701.sh`
- Keep `shells/unlimited_20180701-20190701.sh` opened in some other terminal window `vi shells/unlimited_20180701-20190701.sh` as we need to update all steps. Change all the dates to a new range now so you do not forget and run mixed data.
- First, we need unlimited BigQuery output for a new date range:
```
echo "Restoring BigQuery output"
cp data/data_top30_projects_20180701_20190701.csv data/unlimited.csv
```
- We need the `data/unlimited_output_201807_201907.csv` file. To generate this one, we need to run BigQuery for the new date range.
- Open the sql file that generated the current range's data: `vi BigQuery/query_201807_201907_unlimited.sql`
- Save as `BigQuery/query_201807_201907_unlimited.sql` after changing the date ranges in SQL.
- Copy to clipboard `pbcopy < BigQuery/query_201807_201907_unlimited.sql` and run in Google BigQuery: `https://bigquery.cloud.google.com/queries/<<your_google_project_name>>`, it takes about 1TB and costs about $5
- Save result to a table `<<your_google_user_name>>:unlimited_201807_201907` "Save as table"
- Open this table `<<your_google_user_name>>:unlimited_201807_201907` and click "Export Table" to export it to google storage as: `gs://<<your_google_user_name>>/unlimited_201807_201907.csv` (You may click "View files" to see files in your gstorage)
- Go to google storage and download `<<your_google_user_name>>/unlimited_201807_201907.csv` and put it where `shells/unlimited_20180701-20190701.sh` expects it (update the file name to `data/unlimited_output_201807_201907.csv`): 
```
echo "Restoring BigQuery output"
cp data/unlimited_output_201807_201907.csv data/unlimited.csv
```
- So we have main data (step 1) ready for the new chart. Now we need to get data for all non-standard projects. You can try our analysis tool without any special projects by running:
`ruby analysis.rb data/unlimited.csv projects/unlimited_both.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv`
- It is possible that there will be some new projects that are unknown. Ranks can change during this step, so there can be manual changes needed to mappings in `map/` directory: `hints.csv`, `defmaps.csv` and `urls.csv`. Possibly also in `skip.csv` (if there are new projects that should be skipped)
- This is what came out on the 1st run:
```
Project #23 (org, 457) skillcrush (skillcrush) (skillcrush-104) have no URL defined
Project #45 (org, 366) pivotal-cf (pivotal-cf) (...) have no URL defined
Project #50 (org, 353) Automattic (Automattic) (...) have no URL defined
```

In case you got lost, run these in the velocity root folder:
`cp data/unlimited_output_201807_201907.csv data/unlimited.csv`
`ruby analysis.rb data/unlimited.csv projects/unlimited_both.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv`

- Let's see which top authors projects for those non-found projects are: `rauth[res[res.map { |i| i[0] }.index('Automattic')][0]]`
- Then we must add entries for few top ones in `map/hints.csv` say with >= 20 authors:
```
Automattic/amp-wp,31
Automattic/wp-super-cache,29
Automattic/simplenote-electron,22
Automattic/happychat-service,21
Automattic/kue,20
```
We need to examine each one in `github.com`, like for the 1st project: `github.com/Automattic/amp-wp`. We see that this is a WordPress plugin, so it belnogs to the Wordpress/WP Calypso project:
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
Just add a new repo mapping row for this project in `map/hints.csv`: `Automattic/amp-wp,WP Calypso`
Do the same for other projects/repos. Re-run the analysis tool untill all is fine.
- For example, after defining some new projects we see "EPFL-SV-cpp-projects" in the top 50. This is an educational org that should be skipped. Add it to `map/skip.csv` for skipping row: `EPFL-SV-cpp-projects,,`
- Once You have all URL's defined, added new mapping, you may see a preview of the Top projects on while stopped in `binding.pry`, by typing `all`. Now we need to go back to `shells/unlimited_20180701-20190701.sh` and regenerate all non standard data (for projects not on github or requiring special queries on github - for example because of having 0 activity, comments, commits, issues, prs or authors)

### Linux

- Add a row for the time period in `data/data_linux.csv`: `torvalds,torvalds/linux,2018-07-01,2019-07-01,0,0,0,0,0,0,0,0`
- Get `cncf/gitdm` with `git clone https://github.com/cncf/gitdm.git`
- Get or update local linux kernel repo with `cd ~/dev/linux && git checkout master && git reset --hard && git pull`. An alternative to it (if you don't have the linux repo cloned) is: `cd ~/dev/`, `git clone https://github.com/torvalds/linux.git`.
- Go to `cncf/gitdm/`, `cd ~/dev/cncf/gitdm/src` and run: `./linux_range.sh 2018-07-01 2019-07-01`
- While in `cncf/gitdm/` directory, view: `vim linux_stats/range_2018-07-01_2019-07-01.txt`:
```
Processed 64482 csets from 3803 developers
91 employers found
A total of 3790914 lines added, 1522111 removed (delta 2268803)
```
- You have values for `changesets,additions,removals,authors` here, update `cncf/velocity/data/data_linux.csv` accordingly.
- Final linux row data for the given time period is:
```
torvalds,torvalds/linux,2018-07-01,2019-07-01,64482,3790914,1522111,3803,0,0,0,0
```
- Run `PG_PASS=... ./linux_commits.sh 2018-07-01 2019-07-01` that will give values for number of pushes and commits. This is not needed but recommended. Otherwise put `0,0` for commits and pushes. Changesets are used to calculate output commits.
- Run `./lkml_analysis.rb 2018-07-01 2019-07-01` to get number of LKML emails (all) and new threads.
Run this from the velocity project's root folder again:
`ruby add_linux.rb data/data_lf_projects_20180701_20190701.csv data/data_linux.csv 2018-07-01 2019-07-01`


### CNCF Projects case

- We have a line in `ruby merger.rb data/unlimited.csv data/data_cncf_projects.csv` which needs to be changed to `ruby merger.rb data/unlimited.csv ata/data_cncf_projects_20180701_20190701.csv`

### Gitlab

- GitLab case: Their repo is: `https://gitlab.com/gitlab-org/gitlab-ce`, clone it via: `git clone https://gitlab.com/gitlab-org/gitlab-ce.git` in `~/dev/` directory. If already exists, update with `cd gitlab-ce`, `git pull`
- Their repo hosted by GitHub is: `https://github.com/gitlabhq/gitlabhq`, clone it via `git clone https://github.com/gitlabhq/gitlabhq.git` in `~/dev/` directory. If already exists, update with `cd gitlabhq`, `git pull`. This repo seems not to be used much so we will skip it.
- Go to `cncf/gitdm:src` and run GitLab repo analysis: `./repo_in_range.sh ~/dev/gitlab-ce/ gitlab 2018-07-01 2019-07-01`
- Results are output to `other_repos/gitlab_2018-07-01_2019-07-01.txt`:
```
Processed 16574 csets from 513 developers
15 employers found
A total of 926818 lines added, 548205 removed (delta 378613)
```
- Update `data/data_gitlab.csv` - csets = commits, developers = authors
- Their bug tracker is `https://gitlab.com/gitlab-org/gitlab-ce/issues`, just count issues in the given date range. Sort by "Last created" and count issues in given range:
There are 732 pages of issues (20 per page) = 14640 issues `https://gitlab.com/gitlab-org/gitlab-ce/issues?page=712&scope=all&sort=created_desc&state=all`.
- To count Merge Requests (PRs): `https://gitlab.com/gitlab-org/gitlab-ce/merge_requests?page=454&scope=all&sort=created_date&state=all`.
Merge Requests: 371,5 pages * 20 = 7430
- You can use `./gitlab_issues_and_mrs.sh 'YYYY-MM-DD HH:MM:SS' 'YYYY-MM-DD HH:MM:SS'` to count issues and merge requests too (it is terribly slow).
- To count authors run in gitlab-ce directory: `git log --all --since "2018-07-01" --until "2019-07-01" --pretty=format:"%aE" | sort | uniq | wc -l` --> 575
- To count commits: `git log --all --since "2018-07-01" --until "2019-07-01" --pretty=format:"%H" | sort | uniq | wc -l` (this will return all possible distinct SHA values, maybe some need to be skipped).
- Comments would be 2 * commits, activity = sum of all others (comments, commits, issues, prs)
- Now, that we have the data, it needs to be added to `data/data_gitlab.csv` with a matching date range

### CloudFoundry

- Run `./run_bq.sh cf 2018-07-01 2019-07-01 || echo 'error'` to get Cloud Foundry data. It will generate `data/data_cf_projects_20180701_20190701.csv` file.
- Update (and eventually manually run) the CF case (in `shells/unlimited_20180701-20190701.sh`): `ruby merger.rb data/unlimited.csv data/data_cloudfoundry_201807_201907.csv force`


### OpenStack case

- Newer method - use CNCF devstats contrib instance:
- `cd openstack; PG_PASS=... ./openstack.sh 2018-07-01 2019-07-01 1>/dev/null`
- `./all_openstack.sh 2018-07-01 2019-07-01`.
- `ruby merger.rb data/unlimited.csv openstack/data_openstack_2018-07-01_2019-07-01.csv`.
- New approach: `./openstack_issues.sh '2018-07-01 00:00:00' '2019-07-01 00:00:00'`. Get data from results - it is terribly slow, almost unusable.
- Update file `data/data_openstack_bugs_20180701_20190701.csv` (copy file from `data/data_openstack_bugs.csv`)
- Also create a row for entire OpenStack by summing all issues/PRs/comments.

- Old approach: Use their launch-pad to get [issues count](https://docs.openstack.org/project-team-guide/bugs.html)
Specifically go to: `When you find a bug, you should file it against the proper OpenStack project using the corresponding link`
Click for example "Report a bug in Nova"
https://bugs.launchpad.net/nova/, go to Advanced, select all possible issues, click "Age" sort desc, and then manually count issues in the given date range
Once you have one correct URL, like:
https://bugs.launchpad.net/keystone/+bugs?field.searchtext=&search=Search&field.status%3Alist=NEW&field.status%3Alist=OPINION&field.status%3Alist=INVALID&field.status%3Alist=WONTFIX&field.status%3Alist=EXPIRED&field.status%3Alist=CONFIRMED&field.status%3Alist=TRIAGED&field.status%3Alist=INPROGRESS&field.status%3Alist=FIXCOMMITTED&field.status%3Alist=FIXRELEASED&field.status%3Alist=INCOMPLETE_WITH_RESPONSE&field.status%3Alist=INCOMPLETE_WITHOUT_RESPONSE&assignee_option=any&field.assignee=&field.bug_reporter=&field.bug_commenter=&field.subscriber=&field.structural_subscriber=&field.tag=&field.tags_combinator=ANY&field.has_cve.used=&field.omit_dupes.used=&field.omit_dupes=on&field.affects_me.used=&field.has_patch.used=&field.has_branches.used=&field.has_branches=on&field.has_no_branches.used=&field.has_no_branches=on&field.has_blueprints.used=&field.has_blueprints=on&field.has_no_blueprints.used=&field.has_no_blueprints=on&orderby=-datecreated&memo=350&start=75
You will replace "keystone" with projects names like: nova, glance, swift, horizon etc.
After each replace, click "Age" to sort the created desc. Note how many issues discard from first page (as too new) or next pages.
Then manipulate the "memo" parameter (end of URL) to get a starting value. And choose such value when start date is within. Count issues using memo + #issue which is out - number of issues from 1st (or more) pages which come after.
The url may not e exact as to what you need, Click the gear image just above the first listed bug, select only id and age, hit search. Now you can sort by Age. If page says not found, chances are your start is out of range so start from 0
Estimate for all OpenStack projects (currently 46). Url for Searchlight:
https://bugs.launchpad.net/searchlight/+bugs?field.searchtext=&search=Search&field.status%3Alist=NEW&field.status%3Alist=OPINION&field.status%3Alist=INVALID&field.status%3Alist=WONTFIX&field.status%3Alist=EXPIRED&field.status%3Alist=CONFIRMED&field.status%3Alist=TRIAGED&field.status%3Alist=INPROGRESS&field.status%3Alist=FIXCOMMITTED&field.status%3Alist=FIXRELEASED&field.status%3Alist=INCOMPLETE_WITH_RESPONSE&field.status%3Alist=INCOMPLETE_WITHOUT_RESPONSE&assignee_option=any&field.assignee=&field.bug_reporter=&field.bug_commenter=&field.subscriber=&field.structural_subscriber=&field.tag=&field.tags_combinator=ANY&field.has_cve.used=&field.omit_dupes.used=&field.omit_dupes=on&field.affects_me.used=&field.has_patch.used=&field.has_branches.used=&field.has_branches=on&field.has_no_branches.used=&field.has_no_branches=on&field.has_blueprints.used=&field.has_blueprints=on&field.has_no_blueprints.used=&field.has_no_blueprints=on&orderby=-datecreated&start=0
- The final line should be `ruby update_projects.rb projects/unlimited_both.csv data/data_openstack_bugs_20180701_20190701.csv -1`

### Apache

- Run `./run_bq.sh apache 2018-07-01 2019-07-01 || echo 'error'` to get Apache data. It will generate `data/data_apache_projects_20180701_20190701.csv` file.
- `ruby merger.rb data/unlimited.csv data/data_apache_projects_20180701_20190701.csv`.
- Now we need more data for Apache from their jira, first copy file from previous data range `cp data/data_apache_jira.csv data/data_apache_jira_20180701_20190701.csv`
- New approach (works, but terribly slow): `./apache_jira.sh '2018-07-01 00:00:00' '2019-07-01 00:00:00'` and/or `[REST=1] ./apache_bugzilla.sh '2018-07-01 00:00:00' '2019-07-01 00:00:00'`. `REST=1` can be used once Apache Bugzilla switch to a newer REST API (not yet).
- Final line for Apache should be: `ruby update_projects.rb projects/unlimited_both.csv data/data_apache_jira_20180701_20190701.csv -1`

### Chromium

- Run `./run_bq.sh chromium 2018-07-01 2019-07-01 || echo 'error'` to get Chromium data. It will generate `data/data_chromium_projects_20180701_20190701.csv` file.
- Merge data `ruby merger.rb data/unlimited.csv data/data_chromium_projects_20180701_20190701.csv`.
- Now the manual part: `cp data/data_chromium_bugtracker.csv data/data_chromium_bugtracker_20180701_20190701.csv` (we need to update this file)
- Get Issues from their [bug tracker](https://bugs.chromium.org/p/chromium/issues/list?can=1&q=opened%3E2016%2F7%2F25&colspec=ID+Pri+M+Stars+ReleaseBlock+Component+Status+Owner+Summary+OS+Modified&x=m&y=releaseblock&cells=ids).
Search: All issues + opened>2016/7/19 gives: 63565 (for 2016/7/18 gives 63822+ which means a non exact number) we will extrapolate from here.
All issues + opened>2017/6/1 gives 325, so we have: 63565 - 325 = 63240 issues in 2016-07-19 - 2019-07-01
irb> require 'date'; Date.parse('2019-07-01') - Date.parse('2016-07-19') --> 317
irb> Date.parse('2019-07-01') - Date.parse('2018-07-01') --> 365
irb> 63240.0 * (365.0 / 317.0) --> 72815 
Now add chromedriver to that [count](https://bugs.chromium.org/p/chromedriver/issues/list?can=1&q=opened%3E2016%2F7%2F25&colspec=ID+Pri+M+Stars+ReleaseBlock+Component+Status+Owner+Summary+OS+Modified&x=m&y=releaseblock&cells=ids).
All issues, opened>2017/6/1 --> 1
All issues, opened>2016/6/1 --> 430
So there are 429 chromedriver issues and the total is: 429 + 72815 = 73244
- Now chromium commits analysis which is quite complex
- Their sources (all projects) are here: https://chromium.googlesource.com
- Clone `chromium/src` in `~/dev/src/`: `git clone https://chromium.googlesource.com/chromium/src`. If repo previously cloned, do `cd src/`, `git pull`
- Authors: `git log --all --since "2018-07-01" --until "2019-07-01" --pretty=format:"%aE" | sort | uniq | wc -l` gives 1697
- Commits: `git log --all --since "2018-07-01" --until "2019-07-01" --pretty=format:"%H" | sort | uniq | wc -l` gives 79144 (but this is only FYI, this is way too many, there are bot commits here)
To analyze those commits (also exclude merge and robot commits):
Run while in chromium/src repository:
`git log --all --since "2018-07-01" --until "2019-07-01" --pretty=format:"%aE~~~~%aN~~~~%H~~~~%s" | sort | uniq > chromium_commits_20180701_20190701.csv`
Open the file in `vim`.
Remove special CSV characters with VI commands: `:%s/"//g`, `:%s/,//g`
Replace '~~~~' with ',' to create correct CSV: `:%s/\~\~\~\~/,/g`
Finally add CSV header manually "email,name,hash,subject" 
Save and quit vim.
Then move the file to: `cncf/velocity`:`data/data_chromium_commits_20180701_20190701.csv`: `mv chromium_commits_20180701_20190701.csv ~/dev/cncf/velocity/data/data_chromium_commits_20180701_20190701.csv`
Then run `ruby commits_analysis.rb data/data_chromium_commits_20180701_20190701.csv map/skip_commits.csv`
Script execution will stop so type `quit` and press return/enter
Eventually/optionally add new rules to skip commits to `map/skip_commits.csv`
Tool will output something like this: "After filtering: authors: 1637, commits: 67180" (following regular expressions matched/it had used).
Update `data/data_chromium_bugtracker_20180701_20190701.csv` accordingly.
- Final line should be `ruby update_projects.rb projects/unlimited_both.csv data/data_chromium_bugtracker_20180701_20190701.csv -1`

### OpenSUSE

- Run `./run_bq.sh opensuse 2018-07-01 2019-07-01 || echo 'error'` to get OpenSure data. It will generate `data/data_opensuse_projects_20180701_20190701.csv` file.
- Run `ruby merger.rb data/unlimited.csv data/data_opensuse_projects_20180701_20190701.csv`.

### AGL case (Automotive Grade Linux)

- Also see `docs/linuxfoundation_chart_creation.md`.
- Go to: `https://wiki.automotivelinux.org/agl-distro/source-code` and get source code somewhere:
- `mkdir agl; cd agl`
- `curl https://storage.googleapis.com/git-repo-downloads/repo > repo; chmod +x ./repo`
- `./repo init -u https://gerrit.automotivelinux.org/gerrit/AGL/AGL-repo; ./repo init`
- `./repo sync`
- Now You need to use script `agl/run_multirepo.sh` with: `./run_multirepo.sh` that uses `cncf/gitdm` to generate GitHub-like statistics: `DTFROM=2019-02-01 DTTO=2020-01-01 ./run_multirepo_range.sh`.
- There will be `agl.txt` file generated, something like this:
```
Processed 67124 csets from 1155 developers
52 employers found
A total of 13431516 lines added, 12197416 removed, 24809064 changed (delta 1234100)
```
- You can get number of authors: 1155 and commits 67124 (this is for all time)
- To get data for some specific data range: `cd agl; DTFROM="2018-07-01" DTTO="2019-07-01" ./run_multirepo_range.sh` ==> `agl.txt`.
```
Processed 7152 csets from 365 developers
```
- 7152 commits and 365 authors.
- To get number of Issues, search Jira (old approach): `https://jira.automotivelinux.org/browse/SPEC-923?jql=created%20%3E%3D%202018-07-01%20AND%20created%20%3C%3D%202019-07-01`
- New approach: Use `./agl_jira.sh '2019-02-01 00:00:00' '2020-02-01 00:00:00'`.
- It says 665 issues in a given date range
- PRs = 1.07 * 665 = 711
- Comments would be 2 * commits = 14304
- Activity = sum of all others (comments, commits, issues, prs)
- Finally: `ruby merger.rb data/unlimited.csv data/data_agl_projects_20180701_20190701.csv`

### LibreOffice case

- Run `./run_bq.sh libreoffice 2018-07-01 2019-07-01 || echo 'error'` to get LibreOffice data. It will generate `data/data_libreoffice_projects_20180701_20190701.csv` file.
- Run `ruby merger.rb data/unlimited.csv data/data_libreoffice_projects_20180701_20190701.csv`.
- Now git repo analysis:, first copy `cp data/data_libreoffice_git.csv data/data_libreoffice_git_20180701_20190701.csv` and we will update the `data/data_libreoffice_git_20180701_20190701.csv` file
- Get source code: https://www.libreoffice.org/about-us/source-code/, for example: `git clone git://anongit.freedesktop.org/libreoffice/core` in `~/dev/`. If repo already cloned, do `cd core`, `git pull`
- Analyse this repo as described in: `res/libreoffice_git_repo.txt`, to see that it generates lower number than those from BigQuery output (so we can skip this step)
- Commits: `git log --all --since "2018-07-01" --until "2019-07-01" --pretty=format:"%H" | sort | uniq | wc -l`
- Authors: `git log --all --since "2018-07-01" --until "2019-07-01" --pretty=format:"%aE" | sort | uniq | wc -l`
- Put results in: `data/data_libreoffice_git_20180701_20190701.csv` (authors, commits), values will probably be skipped by the updater tool (they are lower than current values gathered so far)
- Issues (old approach):
- Issue listing is here: `https://bugs.freedesktop.org/buglist.cgi?product=LibreOffice&query_format=specific&order=bug_id&limit=0`
- Create account, change columns to "Opened" and "ID" as generaly no more is needed. (ID is a link). Sort by Opened desc and try to see all results. (You can hit nginx gateway timeout).
- This URL succeeded for me: `https://bugs.documentfoundation.org/buglist.cgi?bug_status=UNCONFIRMED&bug_status=NEW&bug_status=ASSIGNED&bug_status=REOPENED&bug_status=RESOLVED&bug_status=VERIFIED&bug_status=CLOSED&bug_status=NEEDINFO&columnlist=opendate&component=Android%20Viewer&component=Base&component=BASIC&component=Calc&component=Chart&component=ci-infra&component=contrib&component=deletionrequest&component=Documentation&component=Draw&component=Extensions&component=filters%20and%20storage&component=Formula%20Editor&component=framework&component=graphics%20stack&component=Impress&component=Installation&component=LibreOffice&component=Linguistic&component=Localization&component=Printing%20and%20PDF%20export&component=sdk&component=UI&component=ux-advise&component=Writer&component=Writer%20Web&component=WWW&limit=0&list_id=703831&order=opendate%20DESC%2Cchangeddate%2Cbug_id%20DESC&product=LibreOffice&query_format=advanced&resolution=---&resolution=FIXED&resolution=INVALID&resolution=WONTFIX&resolution=DUPLICATE&resolution=WORKSFORME&resolution=MOVED&resolution=NOTABUG&resolution=NOTOURBUG&resolution=INSUFFICIENTDATA`
In the browser window, select rows in range, copy, paste into a text file and see row count. --- OR --- Download as csv to `data/data_libreoffice_bugs.csv`, and then count issues with given date range "2018-07-01" --> "2019-07-01" with `ruby count_issues.rb data/data_libreoffice_bugs.csv Opened '2018-07-01 00:00:00' '2019-07-01 00:00:00'`
```
ruby count_issues.rb data/data_libreoffice_bugs.csv Opened 2018-07-01 2019-07-01
Counting issues in 'data/data_libreoffice_bugs.csv', issue date column is 'Opened', range: 2018-07-01T00:00:00+00:00 - 2019-07-01T00:00:00+00:00
Found 7223 matching issues.
```
Update `data/data_libreoffice_git_20180701_20190701.csv` accordingly.
- New approach, use: `./libreoffice_bugzilla.sh '2018-07-01 00:00:00' '2019-07-01 00:00:00'` (terribly slow).
- Final line should be: `ruby update_projects.rb projects/unlimited_both.csv data/data_libreoffice_git_20180701_20190701.csv -1`

### FreeBSD case

- New approach: Run `./run_bq.sh freebsd 2018-07-01 2019-07-01 || echo 'error'` to get FreeBSD data. It will generate `data/data_freebsd_projects_20180701_20190701.csv` file.
- Run `ruby merger.rb data/unlimited.csv data/data_freebsd_projects_20180701_20190701.csv`.
- Use `BigQuery/org_finder.sql` (with condition '%freebsd%' to find FreeBSD orgs). Check all of them on GitHub and create final BigQuery:
- `cp BigQuery/query_apache_projects.sql BigQuery/query_freebsd_projects.sql` and update conditions, run query, download results, put them in `data/data_freebsd_projects20180701_20190701.csv` (if there aren't many rows, just Download as CSV, othervise: save as table, export to gstorage, download csv)
- Now define FreeBSD project the same way as in BigQuery: put orgs in `map/defmaps.csv`, put URL in `map/urls.csv`, put orgs as exceptions in `map/ranges.csv` and `map/ranges_sane.csv` (because some values can be 0s due to custom BigQuery)
- Add FreeBSD processing to shells/unlimited:
```
echo "Adding/Updating FreeBSD Projects"
ruby merger.rb data/unlimited.csv data/data_freebsd_projects_20180701_20190701.csv
```
- Go to `~/dev/freebsd` and clone 3 SVN repos:
```
svn checkout https://svn.freebsd.org/base/head base
svn checkout https://svn.freebsd.org/doc/head doc
svn checkout https://svn.freebsd.org/ports/head ports
```
- `svn update` all of them if you already have them.
- Use `cncf/gitdm/src/freebsd_svn.sh` script to analyse FreeBSD SVN repos with `./freebsd_svn.sh 20180701 20190701`:
```
Revisions:    35927
Authors:      335
```
- Put results here (authors and commits): `./data/data_freebsd_svn_20180701_20190701.csv`
- Go to: `https://docs.freebsd.org/mail/` and estimate number of emails for your period.
- Old approach: Go to [FreeBSD Bugzilla](https://bugs.freebsd.org/bugzilla/buglist.cgi?chfield=%5BBug%20creation%5D&chfieldfrom=2018-07-01&chfieldto=2019-07-01&order=Last%20Changed&query_format=advanced) and get number of bugs in a given period (bugs=issues, prs=issues).
- Go to search, choose 'advanced search' then 'custom search' then choose 'show advanced features'). Use 'Creation data' column twice. First for greater or equal than YYYY-MM-DD than less or equal to YYYY-MM-DD.
- Click search, results will be limited to first 500, click change columns and choose 'Opened' only (it will show ID and Opened then), finally [url](https://bugs.freebsd.org/bugzilla/buglist.cgi?columnlist=opendate&f1=creation_ts&f2=creation_ts&limit=0&o1=greaterthaneq&o2=lessthaneq&order=opendate%2Cchangeddate%2Cbug_status%2Cpriority%2Cassigned_to%2Cbug_id&query_format=advanced&v1=2018-07-01&v2=2019-07-01).
- New approach: `./freebsd_bugzilla.sh '2018-07-01 00:00:00' '2019-07-01 00:00:00'` (terribly slow).
- Put results here (comments=emails/3 (many of them are automatic)): `./data/data_freebsd_svn_20180701_20190701.csv`
- Finally `ruby update_projects.rb projects/unlimited_both.csv ./data/data_freebsd_svn_20180701_20190701.csv`.
- Use the above two values in a copy of this file: `data_freebsd_svn_20180701_20190701.csv`
- Now rerun `shells/unlimited_20180701_20190701.sh` and see FreeBSD's rank along with the remaining final results.


### Remove non-code projects

Imporant:
- Some projects are already defined in `map/skip.csv` but examine `projects/unlimited_both.csv` and remove documentation related projects etc (we want to track them to see changes, but we don not want them in the final report).
- Example: MicrosoftDocs, TheOdinProject
- We may also want to remove some full-orgs which aren't a single project, like: ibm, intel, hashicorp, mozilla - but finally you need to split out separate projects from them.

### Generate final data
- Now rerun `shells/unlimited_both.sh`.
- When script is done running, a file `./projects/unlimited.csv` is (re)/generated. You need to import it in Google chart by doing:
- Select the cell A50. Use File --> Import, then "Upload" tab, "Select a file from your computer", choose `./projects/unlimited.csv`
- Then "Import action" --> "replace data starting at selected call", click Import.
- Switch to the Chart tab and see the data.

Final version live [here](https://docs.google.com/spreadsheets/d/14ALEBOqyLZPudxaf7gAWZPBLjDy_RMiYwaobDdBYOLs/edit?usp=sharing).

### Results:

NOTE: for viewing using those motion charts You'll need Adobe Flash enabled when clicking links. It works (tested) on Chrome and Safari with Adobe Flash installed and enabled.

For data from files.csv (data/data_YYYYMM.csv), 201807 --> 201907 (15 months)
Chart with cumulative data (each month is sum of this month and previous months) is here:
https://docs.google.com/spreadsheets/d/11qfS97WRwFqNnArRmpQzCZG_omvZRj_y-MNo5oWeULs/edit?usp=sharing
Chart with monthly data (that looks wrong IMHO due to google motion chart data interpolation between months) is here: 
https://docs.google.com/spreadsheets/d/1ZgdIuMxxcyt8fo7xI1rMeFNNx9wx0AxS-2a58NlHtGc/edit?usp=sharing

Playing around with the 1st chart (cumulative sum):
It is not able to remember settings so once you click on "Chart1" scheet suggest action is to:
- Change axis-x and axis-y from Lin (linerar) to Log (logarithmics)
- You can choose what column should be used for color: like activity (this is default and shows which project was most active) or choose unique color (You can select from commits, prs+issues, size) (size is square root of number of authors)
- Change playback speed (control next to play) to slowest
- Select inerested projects from Legend (like Kubernetes for example or Kubernetes vs dotnet etc) and check "trails"
- You can also change what x and y axisis use as data, defaults are: x=commits, y=pr+issues, and change scale type lin/log
- You can also change which column is used for bubble size (default is "size" which means square root of number of authors), note that the number of authors = max from all months (distinct authors that contributed to activity), this is obviously different from set of distinct authors activity in the entire 15 months range

On the top/right just above the Color drop down you will see additional two chart types:
- Bar chart - this can be very useful
- Choose li or log y-axis scale, then select Kubernetes from Legend and then choose any of y-axis possible values (activity, commits, PRs+issues, Size) and click play to see how Kubernetes overtakes multiple projects during our period.
Finally there is also a linear chart, take a look at it as well.
