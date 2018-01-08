# velocity
## Track development velocity

This tool set generates data for a Bubble/Motion Google Sheet Chart.<br/>The main script is `analysis.rb`. The input is a csv file created from BigQuery results. 

This tool is being used for periodical chars update as described in the following documents:<br/>
[Guide to the CNCF projects chart creation](docs/cncf_chart_creation.md)<br/>
[Guide to the LinuxFoundation projects chart creation](docs/linuxfoundation_chart_creation.md)<br/>
[Guide to the Top-30 projects chart creation](docs/top30_chart_creation.md)

https://www.cncf.io/blog/2017/06/05/30-highest-velocity-open-source-projects/ <br/>
[Links to various charts and videos generated using this project](res/links.txt)

### Example use:
`ruby analysis.rb data/data_yyyymm.csv projects/projects_yyyymm.csv map/hints.csv map/urls.csv map/defmaps.csv skip.csv ranges.csv`

Depending on data, the script will stop execution and present a command line. 
```
[1] pry(main)>
```
To continue, type 'quit' and hit enter/return.

Arguments list:
- data file, points to the results of running an sql statement designed for Google BigQuery. The query generates a standardized (in terms of velocity) header. The `.sql` files are stored in `BigQuery/` folder
- output file, typically a new file in the `projects/` folder
- a "hints" file with additional mapping: repo name -> project. (N repos --> 1 Project), so a given project name may be listed be in many lines
- a "urls" file which defines URLs for the listed projects (a separate file is used because otherwise, in hints file we would have to duplicate data for each project ) (1 Project --> 1 URL)
- a "default" map file which defines non standard names for projects generated automatically via grouping by org (like aspnet --> ASP.net) or to group multiple orgs and/or repos into a single project. It is the last step of project name mapping
This tool outputs a data file into the 'projects/' directory
- a "skip" file that lists repos and/or orgs and/or projects to be skipped
- a "ranges" file that contains ranges of repos properties which makes repo included in calculations

### File formats
`input.csv` data/data_yyyymm.csv from BigQuery, like the following:
```
org,repo,activity,comments,prs,commits,issues,authors
kubernetes,kubernetes/kubernetes,11243,9878,720,70,575,40
ethereum,ethereum/go-ethereum,10701,570,109,43,9979,14
...
```

`output.csv` to be imported via Google Sheet (File -> Import) and then chart created from this data. It looks like this:
```
org,repo,activity,comments,prs,commits,issues,authors,project,url
dotnet,corefx+coreclr+roslyn+cli+docs+core-setup+corefxlab+roslyn-project-system+sdk+corert+eShopOnContainers+core+buildtools,20586,14964,1956,1906,1760,418,dotnet,microsoft.com/net
kubernetes+kubernetes-incubator,kubernetes+kubernetes.github.io+test-infra+ingress+charts+service-catalog+helm+minikube+dashboard+bootkube+kargo+kube-aws+community+heapster,20249,15735,2013,1323,1178,423,Kubernetes,kubernetes.io
...
```

`hints.csv` a csv file with hints for repo --> project mapping, it has this format:
```
repo,project
Microsoft/TypeScript,Microsoft TypeScript
...
```

`urls.csv` a csv file with project --> url mapping with the following format:
```
project,url
Angular,angular.io
...
```

`defmaps.csv` a csv file with proper names for projects generated as default groupping within org:
```
name,project
aspnet,ASP.net
nixpkgs,NixOS
Azure,=SKIP
...
```
The special flag '=SKIP' for a project means that this org should NOT be groupped

`skip.csv` a csv file that contains lists of repos and/or orgs and/or projects to be skipped in the analysis:
```
org,repo,project
"enkidevs,csu2017sp314,thoughtbot,illacceptanything,RubySteps,RainbowEngineer",Microsoft/techcasestudies,"Apache (other),OpenStack (other)"
"2015firstcmsc100,swcarpentry,exercism,neveragaindottech,ituring","mozilla/learning.mozilla.org,Microsoft/HolographicAcademy,w3c/aria-practices,w3c/csswg-test",
"orgX,orgY","org1/repo1,org2/repo2","project1,project2"
```

`ranges.csv` a csv file that contains ranges of repos properties which makes repo included in calculations.
It can constrain any of "commits, prs, comments, issues, authors" to be within range n1 .. n2 (if n1 or n2 < 0 then this value is skipped, so -1..-1 means unlimited
There can be also be exception repos/orgs that do not use those ranges:
```
key,min,max,exceptions
activity,50,-1,"kubernetes,docker/containerd,coreos/rkt"
comments,20,100000,"kubernetes,docker/containerd,coreos/rkt"
prs,10,-1,"kubernetes,docker/containerd,coreos/rkt"
commits,10,-1,"kubernetes,kubernetes-incubator"
issues,10,-1,"kubernetes,docker/containerd,coreos/rkt"
authors,3,-1,"kubernetes,docker/containerd,google/go-github"
```

The generated output file contains all the input data (so it can be 600 rows for 1000 input rows for example).
You should manually review generated output and choose how many rocords you need.

`hintgen.rb` is a tool that takes data already processed for various created charts and creates distinct projects hint file from it. Example usage:

`hintgen.rb data.csv map/hints.csv`
Use multiple times putting a different data file (1st parameter) and generate final `hints.csv`.


### Input and Output
Data files existing in the repository:
- data/data_YYYYMM.csv --> data for given YYYYMM from BigQuery.
- projects/projects_YYYYMM.csv --> data generated by `analysis.rb` based on data_YYYYMM.csv with `map/`: `hints.csv`, `urls.csv`, `defmaps.csv`, `skip.csv`, `ranges.csv` parameters


### Motion charts
`generate_motion.rb` a tool that merges data from multiple files into one to be used for motion chart. Usage:

`ruby generate_motion.rb projects/files.csv motion/motion.csv motion/motion_sums.csv [projects/summaries.csv]`

File `files.csv` contains a list of data files to be merged. It has the following format:
```
name,label
projects/projects_201601.csv,01/2016
projects/projects_201602.csv,02/2016
...
```

This tool generates 2 output files:
- 1st is a motion data from each file with a given label
- 2nd is cumulative sum of data, so 1st label contains data from 1st label, 2nd contains 1st+2nd, 3rd=1st+2nd+3rd ... last = sum of all data. Labels are summed-up in alphabetical order. When input data is divided by months, "YYYYMM" or "YYYY-MM" format must be used to receive correct results. "MM/YYYY" will, for example, swap "2/2016" and "1/2017".<br />Output formats of 1st and 2nd files are identical.<br />The first column is a data file generated by `analysis.rb`. The following column is a label that will be used as "time" for google sheets motion chart.

Output format:
```
project,url,label,activity,comments,prs,commits,issues,authors,sum_activity,sum_comments,sum_prs,sum_commits,sum_issues,sum_authors
Kubernetes,kubernetes.io,2016-01,6289,5211,548,199,331,73,174254,136104,18264,8388,11498,373
Kubernetes,kubernetes.io,2016-02,13021,10620,1180,360,861,73,174254,136104,18264,8388,11498,373
...
Kubernetes,kubernetes.io,2017-04,174254,136104,18264,8388,11498,373,174254,136104,18264,8388,11498,373
dotnet,microsoft.com/net,2016-01,8190,5933,779,760,718,158,158624,111553,17019,17221,12831,382
dotnet,microsoft.com/net,2016-02,17975,12876,1652,1908,1539,172,158624,111553,17019,17221,12831,382
...
dotnet,microsoft.com/net,2017-04,158624,111553,17019,17221,12831,382,158624,111553,17019,17221,12831,382
VS Code,code.visualstudio.com,2016-01,7526,5278,381,804,1063,112,155621,104386,9501,17650,24084,198
VS Code,code.visualstudio.com,2016-02,17139,11638,986,1899,2616,133,155621,104386,9501,17650,24084,198
...
VS Code,code.visualstudio.com,2017-04,155621,104386,9501,17650,24084,198,155621,104386,9501,17650,24084,198
...
```
Each row contains its label data (separate or cumulative) whereas columns with starting with `max_` contain cumulative data for all labels.
This is to make the data ready for google sheet motion chart without complex cell indexing.

The final (optional) file `summaries.csv` is used to read the number of authors. This is because the number of authors is computed differently.
Without the summaries file (or if a given project is not in the summaries file), we have a number of distinct authors in each period. Summary value is a sum of all periods max.
This is obviously not a real count of all distinct authors in all periods. Number of authors would be computed if another file is supplied, one which contains summary data for a longer period that is equal to sum of all periods.


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


### More info

[Guide to non-GitHub project processing](docs/non_github_repositories.md)

[Other useful notes](docs/other_notes.md)

