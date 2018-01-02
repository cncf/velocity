[<- Back to the cncf/velocity README.md file](../README.md)

[Guide to non-github project processing](docs/non_github_repositories.md)

### Processing unlimited BigQuery data

This means removing some filtering out of BigQuery and letting Ruby tools perform the task instead.

To process "unlimited" data from BigQuery output (file `data/unlimited.csv`) , use `shells/unlimited.sh` or `shells/unlimited_both.sh`).
Unlimited means that BigQuery is not constraining repositories by having commits, comments, issues, PRs, authors > N (this N is 5-50 depending on which metric: authors for example is 5 while comments is 50).
Unlimited only requires that authors, comments, commits, prs, issues are all > 0.
And then only CSV `map/ranges_unlimited.csv` is used to further constrain data. This basically moves filtering out of BigQuery (so it can be called once) to the Ruby tool.
And `shells/unlimited_both.sh` uses `map/ranges_unlimited.csv` that is not setting ANY limit:
```
key,min,max,exceptions
activity,-1,-1,
comments,-1,-1,
prs,-1,-1,
commits,-1,-1,
issues,-1,-1,
authors,-1,-1,
```
It means that mapping must have extremely long list of projects from repos/orgs to get valid non obfuscated data.

You can skip a ton of organization's small repos (if they do not sum up to just few projects, while they are distinct), with:
`rauth[res[res.map { |i| i[0] }.index('Google')][0]].select { |i| i.split(',')[1].to_i < 14 }.map { |i| i.split(',')[0] }.join(',')`
The following is an example based on Google.
Say Top 100 projects have 100th project with 290 authors.
All tiny google repos (distinct small projects) will sum up and make Google overall 15th (for example).
The above command generates output list of google repos with 13 authors or less . You can put the results in map/skip.csv" and then You'll avoid false positive top 15 for Google overall (which would not be true)

### Adding external projects' data

There is also a tool to add data for external projects (not hosted on GitHub): `add_external.rb`.
It is used by `shells/unlimited.csv` and `shells/unlimited_both.sh`
Example call:
`ruby add_external.rb data/unlimited.csv data/data_gitlab.csv 2016-05-01 2017-05-01 gitlab gitlab/GitLab`
It requires a csv file with external repo data.
It must be defined per date range.
It has this format (see `data/data_gitlab.csv` for example):
```
org,repo,from,to,activity,comments,prs,commits,issues,authors
gitlab,gitlab/GitLab,2016-05-01,2017-05-01,40000,40000,11595,9479,22821,1500

```

There is also a tool to update generated projects file which in turn is used to import data for charts.
`update_projects.rb`
Listed in `shells/unlimited_both.sh`
It is used to update certain values in given projects
It processes an input file with the following format:
```
project,key,value
Apache Mesos,issues,7581
Apache Spark,issues,5465
Apache Kafka,issues,1496
Apache Camel,issues,1284
Apache Flink,issues,2566
Apache (other),issues,52578
```
This allows updating specific keys in specific projects with data taken from sources other than GitHub.
It is currently being used to update github data with issues statistics from jira (for apache projects).


### Project ranks

Tool to create ranks per project (for all project's numeric properties) `report_projects_ranks.rb` & `shells/report_cncf_project_ranks.sh`
Shell script projects from `projects/unlimited_both.csv` and uses: `reports/cncf_projects_config.csv` file to get a list of projects that needs to be included in the rank statistics.
File format is:
```
project
project1
project2
...
projectN
```
It outputs a rank statistics file `reports/cncf_projects_ranks.txt`



### Examples of external (non-GitHub) data processing

For special cases (see `./shells/unlimited_both.sh` which calls all scripts in the correct order)
Some details about adding external data from non-GitHub projects:
- How to find Apache issues in Jira: `res/data_apache_jira.query`

- Case with Chromium: (details here: `res/data_chromium_bugtracker.txt`), issues from their bugtracker, number of authors and commits in date range via `git log` one-liner:
Must be called in Git repo cloned from GoogleSource (not from github): `git clone https://chromium.googlesource.com/chromium/src`
Commits: `git log --since "2016-05-01" --until "2017-05-01" --pretty=format:"%H" | sort | uniq | wc -l` gives 77437
Authors: `git log --since "2016-05-01" --until "2017-05-01" --pretty=format:"%aE" | sort | uniq | wc -l` gives 1663
To analyze those commits (such as to exclude merge and robot commits):
data/data_chromium_commits.csv, run while in chromium/src repository:
`git log --since "2016-05-01" --until "2017-05-01" --pretty=format:"%aE~~~~%aN~~~~%H~~~~%s" | sort | uniq > chromium_commits.csv`
Then remove special csv characters with VI commands: `:%s/"//g`, `:%s/,//g`
Then add a csv header row manually "email,name,hash,subject" and move it to: `data/data_chromium_commits.csv`
Finally replace '~~~~' with ',' to create correct csv: `:%s/\~\~\~\~/,/g`
Then run `ruby commits_analysis.rb data/data_chromium_commits.csv map/skip_commits.csv` or `./shells/chromium_commits_analysis.sh`

- Case with OpenStack: `res/data_openstack_lanuchpad.query` - data from their launchpad

- Case with WebKit: `res/data_webkit_links.txt` issues from their bug tracker: `https://webkit.org/reporting-bugs/`
For authors and commits, 3 different tools were tried: our cncf/gitdm on their webkit/WebKit github repo, git one-liner on the same repo (`git clone git://git.webkit.org/WebKit.git WebKit`):
Authors: 121: `git log --since "2016-05-01" --until "2017-05-01" --pretty=format:"%aE" | sort | uniq | wc -l`
Authors: 121: `git log --since "2016-05-01" --until "2017-05-01" --pretty=format:"%cE" | sort | uniq | wc -l`
Commits: 13051: `git log --since "2016-05-01" --until "2017-05-01" --pretty=format:"%H" | sort | uniq | wc -l`
Our cncf/gitdm output files are also stored here: `res/webkit/`: WebKit_2016-05-01_2017-05-01.csv  WebKit_2016-05-01_2017-05-01.txt

Also tried SVN one liner on their original SVN repo (due to the fact that its Github repo is only a mirror): 
To fetch SVN repo:
`svn checkout https://svn.webkit.org/repository/webkit/trunk WebKit`
or:
`tar jxvf WebKit-SVN-source.tar.bz2`
`cd webkit`
`svn switch --relocate http://svn.webkit.org/repository/webkit/trunk https://svn.webkit.org/repository/webkit/trunk`
Finally run their script: `update-webkit`

Number of commits: svn log -q -r {2016-05-01}:{2017-05-01} | sed '/^-/ d' | cut -f 1 -d "|" | sort | uniq | wc -l
Number of authors: svn log -q -r {2016-05-01}:{2017-05-01} | sed '/^-/ d' | cut -f 2 -d "|" | sort | uniq | wc -l
To get the data from SVN:
Revisions: svn log -q -r {2017-05-25}:{2017-05-26} | sed '/^-/ d' | cut -f 1 -d "|"
Authors: svn log -q -r {2017-05-25}:{2017-05-26} | sed '/^-/ d' | cut -f 2 -d "|"
Dates: svn log -q -r {2017-05-25}:{2017-05-26} | sed '/^-/ d' | cut -f 3 -d "|"

- GitLab estimation and details here: `res/gitlab_estims.txt`
- LibreOffice case: see `res/libreoffice_git_repo.txt`

### Special GitHub projects (like mirrors, backups etc.)
To add a new non-standard project (but from github mirros, which can have 0s on comments, commits, issues, prs, activity, authors) follow this route:
- Copy `BigQuery/org_finder.sql` to clipboard and run this on BigQuery replacing condition for org (for example lower(org.login) like '%your%org%)
- Examine output org/repos combination (manually on GitHub) and decide about final condition for the final BigQuery run
- Copy `BigQuery/query_apache_projects.sql` into some `BigQuery/query_your_project.sql` then update conditions to those found in the previous step
- Run the query
- Save results to a table. Export this table to GStorage. Download this table as CSV from GStorage into `data/data_your_project_datefrom_date_to.csv`
- Add this to `shells/unlimited_both.csv`:
```
echo "Adding/Updating YourProject case"
ruby merger.rb data/unlimited.csv data/data_your_project_datefrom_date_to.csv
```
- Update `map/range*.csv` - add exception for YourProject (because it can have 0s now - this is output from BigQuery without numeric conditions)
- Run `shells/unlimited_both.sh` and examine Your Project (few iterations to add correct mapping in `./map/`: hints, defmaps, urls etc.)
- You can run manually: `ruby analysis.rb data/unlimited.csv projects/unlimited_both.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv`
- For example see YourProject rank: `res.map { |i| i[0] }.index('LibreOffice')` or `res[res.map { |i| i[0] }.index('LibreOffice')][2][:sum]`
- Some of the values will be missing (like for example PRs for mirror repos)
- Now it is time for a non standard path, please see `shells/unlimited_both.sh` for non standar data update that comes after final `ruby analysis.rb` call - this is usually different for each non-standard project

### How to find bots to be excluded in queries for project data
Two queries were created to be run in GoogleBigQuery. One for CloudFoundry, one for Chromium. Take a look at
`query_cloudfoundry_authors_from_to.sql` 
The result is in 
`data_cloudfoundry_authors_201611_201710.csv`
A bot can be spotted visually in the row where author (github login) is 'coveralls'
```
activity,comments,prs,commits,issues,author
1246,330,104,700,112,frodenas
1210,1210,0,0,0,coveralls
1164,88,58,979,39,genevievelesperance
```
The other authors can be validated to be human by going to address such as https://github.com/frodenas

Another way to identify bots would be by means af a query such as `query_chromium_authors_v2_from_to.sql` which lists names and counts of their commits. A results file such as `data_chromium_authors_v2_201611_2017_10.csv` brings data as follows:
```
activity,comments,prs,commits,issues,author_name
30583,17349,5997,25,7212,(null)
1549,0,0,1549,0,Matt Gaunt
857,0,0,857,0,Paul Irish
... ... ...
125,0,0,125,0,DevTools Bot
```

Bots should be excluded from the data queries and future bot hunting queries as to not duplicate efforts.
