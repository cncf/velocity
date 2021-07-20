[Back to the cncf/velocity README.md file](../README.md)

[Guide to non-github project processing](non_github_repositories.md)

[Other useful notes](other_notes.md)

## Guide to the Linux Foundation projects chart creation

`analysis.rb` can be used to create data for a Cloud Native Computing Foundation projects bubble chart such as this one
![sample chart](./linuxfoundation_chart_example.png?raw=true "CNCF projects")

The chart itself can be generated in a [google sheet](https://docs.google.com/spreadsheets/d/1dCe99AyOEhQhuEyhwIn_P2thVtjQXF1cGFiLo8fhZZM/edit#gid=134798507).

### Chart data
Go to this [CNCF page](https://www.linuxfoundation.org/projects/) to find a list of current projects.

For every project, find a github repo and add it to a [query](BigQuery/velocity_lf.sql) appropriately - either as an org or a single repo or both. If a project does not have a GitHub repo or only lists a mirror, skip it for now but later add manually.

Run the query for a year, for example: `./run_bq.sh lf 2018-07-01 2019-07-01`. It takes about 1+TB and costs about $5+.

It will generate a file for example: `data/data_lf_projects_20180701_20190701.csv`.

### Add CNCF projects

You may miss CSV header, add `org,repo,activity,comments,prs,commits,issues,authors_alt2,authors_alt1,authors,pushes` if needed.

- `ruby merger.rb data/data_lf_projects_20180701_20190701.csv data/data_cncf_projects_20180701_20190701.csv`.


### Add Linux data

Try running this from the velocity project's root folder:
`ruby add_linux.rb data/data_lf_projects_20180701_20190701.csv data/data_linux.csv 2018-07-01 2019-07-01`.
- A message will be shown: `Data range not found in data/data_linux.csv: 2018-07-01 - 2019-07-01`. That means you need to add a new data range for Linux in file: `data/data_linux.csv`
- Add a row for the time period in `data/data_linux.csv`: `torvalds,torvalds/linux,2016-11-01,2017-11-01,0,0,0,0,0,0,0,0`
	- Get `cncf/gitdm` with `git clone https://github.com/cncf/gitdm.git`
	- Get or update local linux kernel repo with `cd ~/dev/linux && git checkout master && git reset --hard && git pull`. An alternative to it (if you don't have the linux repo cloned) is: `cd ~/dev/`, `git clone https://github.com/torvalds/linux.git`.
	- Go to `cncf/gitdm/`, `cd ~/dev/alt/gitdm/src` and run: `./linux_range.sh 2018-07-01 2019-07-01`
	- While in `cncf/gitdm/` directory, view: `vim linux_stats/range_2018-07-01_2019-07-01.txt`:
	```
	Processed 64482 csets from 3803 developers
	91 employers found
	A total of 3790914 lines added, 1522111 removed (delta 2268803)
	```
	- You have values for `changesets,additions,removals,authors` here, update `cncf/velocity/data/data_linux.csv` accordingly.
	- Final linux row data for the given time period is:
	```
	torvalds,torvalds/linux,2016-06-01,2017-06-01,64482,3790914,1522111,3803,0,0,0,0
	```
- Create `devstats-reports` pod, shell into it and run: `./velocity/linux_commits.sh 2018-07-01 2019-07-01` that will give values for number of pushes and commits. This is not needed but recommended. Otherwise put `0,0` for commits and pushes. Changesets are used to calculate output commits.
- Run `./lkml_analysis.rb 2018-07-01 2019-07-01` to get number of LKML emails (all) and new threads.
Run this from the velocity project's root folder again:
`ruby add_linux.rb data/data_lf_projects_20180701_20190701.csv data/data_linux.csv 2018-07-01 2019-07-01`.


### Add AGL (Automotive Grade Linux) data

- Go to: https://wiki.automotivelinux.org/agl-distro/source-code and get source code somewhere:
- `mkdir agl; cd agl`
- `curl https://storage.googleapis.com/git-repo-downloads/repo > repo; chmod +x ./repo`
- `./repo init -u https://gerrit.automotivelinux.org/gerrit/AGL/AGL-repo; ./repo init`
- `./repo sync`
- Now You need to use script `agl/run_multirepo.sh` with: `./run_multirepo.sh` that uses `cncf/gitdm` to generate GitHub-like statistics.
- `DTFROM=2018-07-01 DTTO=2019-07-01 ./run_multirepo_range.sh`.
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
- To get number of Issues, search Jira (old approach): `https://jira.automotivelinux.org/browse/SPEC-923?jql=created%20%3E%3D%202016-10-01%20AND%20created%20%3C%3D%202017-10-01`
- Use `./agl_jira.sh '2017-11-01 00:00:00' '2018-11-01 00:00:00'`.
- It will return the number of issues in a given time range.
- PRs = 1.07 * 665 = 711
- Comments would be 2 * commits = 14304
- Activity = sum of all others (comments, commits, issues, prs)
- Create a file based on `data/data_agl_projects_20180701_20190701.csv` and apply proper data values
- Run `ruby merger.rb data/data_lf_projects_20180701_20190701.csv data/data_agl_projects_20180701_20190701.csv`.

Run `analysis.rb` with
```
ruby analysis.rb data/data_lf_projects_20180701_20190701.csv projects/projects_lf_20180701_20190701.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv
```

Now update CNCF projects commits counts to use git instead of BigQuery data

If you generated CNCF data just before generating LF data, then you already have that step completed, see [Guide to the CNCF projects chart creation](docs/cncf_chart_creation.md).

- Create `devstats-reports` pod, shell into it and run: `./velocity/update_cncf_projects_commits.sh 2019-02-01 2020-02-01`.
- Download update: `wget https://teststats.cncf.io/backups/data_cncf_update_2019-02-01_2020-02-01.csv`. `mv data_cncf_update_2019-02-01_2020-02-01.csv data/`.
- `ruby update_projects.rb projects/projects_lf_20180701_20190701.csv data/data_cncf_update_2018-07-01_2019-07-01.csv -1`.
- You can also use `PROJFMT=1 ruby update_projects.rb projects/projects_lf_20180701_20190701.csv ./projects/projects_cncf_20190201_20200201.csv -1` instead.

Make a copy of the [google doc](https://docs.google.com/spreadsheets/d/1gNxnUjGB6P1RZMngdZWao2OqQvNl3D6yf5DWMWU218M/edit?usp=sharing).

Put results of the analysis into a file and import the data in the 'Data' sheet in cell A200.
File -> Import -> Upload -> in the Import location section, select the radio button called 'Replace data at selected cell', click Import data

Select the Chart tab, it will be updated automatically

CloudFoundry PRs and Issues counts need manual adjustment in the Data tab of the google doc.

Use `[DROP=1] PG_PASS=... ./cloudfoundry/run.sh 2019-02-01 2020-02-01` shell scripts to get this data.

Use `PG_PASS=.. ./cloudfoundry/see_committers.sh actor_col` to debug and see top commit per specified actor column.
