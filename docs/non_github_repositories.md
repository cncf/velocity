[Back to the cncf/velocity README.md file](../README.md)

[Other useful notes](other_notes.md)

### Adding non-GitHub projects

To manually add other projects (like Linux) use `add_linux.sh` or create similar tools for other projects. Data for this tool was generated manually using a custom `gitdm` tool (`github cncf/gitdm`) on `torvalds/linux` repo and via manually counting email addresses in different periods on LKML.
Example usage, assuming that Linux additional data is in `data/data_linux.csv`, could be: 
`ruby add_linux.rb data/data_201603.csv data/data_linux.csv 2016-03-01 2016-04-01`

A larger scope (e.g. GitHub data) file can be injected with such custom script results data (from Gitlab or Linux or External) by the merger script:
`ruby merger.rb file_to_merge.csv file_to_get_data_from.csv`
See for example `./shells/top30_201605_201704.sh`
Every merge will compound data into the merger file.


### Examples of external (non-GitHub) data processing

For special cases (see `./shells/unlimited_both.sh` which calls all scripts in the correct order)
Some details about adding external data from non-GitHub projects:
- How to find Apache issues in Jira: `res/data_apache_jira.query`

- Case with Chromium: (details here: `res/data_chromium_bugtracker.txt`), issues from their bugtracker, number of authors and commits in date range via `git log` one-liner:
Must be called in Git repo cloned from GoogleSource (not from github): `git clone https://chromium.googlesource.com/chromium/src`
Commits: `git log --all --since "2016-05-01" --until "2017-05-01" --pretty=format:"%H" | sort | uniq | wc -l` gives 77437
Authors: `git log --all --since "2016-05-01" --until "2017-05-01" --pretty=format:"%aE" | sort | uniq | wc -l` gives 1663
To analyze those commits (such as to exclude merge and robot commits):
data/data_chromium_commits.csv, run while in chromium/src repository:
`git log --all --since "2016-05-01" --until "2017-05-01" --pretty=format:"%aE~~~~%aN~~~~%H~~~~%s" | sort | uniq > chromium_commits.csv`
Then remove special csv characters with VI commands: `:%s/"//g`, `:%s/,//g`
Then add a csv header row manually "email,name,hash,subject" and move it to: `data/data_chromium_commits.csv`
Finally replace '~~~~' with ',' to create correct csv: `:%s/\~\~\~\~/,/g`
Then run `ruby commits_analysis.rb data/data_chromium_commits.csv map/skip_commits.csv` or `./shells/chromium_commits_analysis.sh`

- Case with OpenStack: `res/data_openstack_lanuchpad.query` - data from their launchpad
- You can use devstats contrib database.

- Case with WebKit: `res/data_webkit_links.txt` issues from their bug tracker: `https://webkit.org/reporting-bugs/`
For authors and commits, 3 different tools were tried: our cncf/gitdm on their webkit/WebKit github repo, git one-liner on the same repo (`git clone git://git.webkit.org/WebKit.git WebKit`):
Authors: 121: `git log --all --since "2016-05-01" --until "2017-05-01" --pretty=format:"%aE" | sort | uniq | wc -l`
Authors: 121: `git log --all --since "2016-05-01" --until "2017-05-01" --pretty=format:"%cE" | sort | uniq | wc -l`
Commits: 13051: `git log --all --since "2016-05-01" --until "2017-05-01" --pretty=format:"%H" | sort | uniq | wc -l`
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
