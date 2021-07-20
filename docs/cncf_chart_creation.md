[Back to the cncf/velocity README.md file](../README.md)

[Guide to non-github project processing](non_github_repositories.md)

[Other useful notes](other_notes.md)

## Guide to the CNCF projects chart creation

`analysis.rb` can be used to create data for a Cloud Native Computing Foundation projects bubble chart such as this one
![sample chart](./cncf_chart_example.png?raw=true "CNCF projects")

The chart itself can be generated in a [google sheet](https://docs.google.com/spreadsheets/d/1S1Yq-Z4Iir49Uu3L0bWA5hEVDcsOrrGrtgJ5PH2dIKk/edit?usp=sharing).

### Chart data
Go to this [CNCF page](https://www.cncf.io/projects/) to find a list of current projects.

For every project, find a github repo and add it to a [query](BigQuery/velocity_cncf.sql) appropriately - either as an org or a single repo or both. If a project does not have a GitHub repo or only lists a mirror, skip it for now but later add manually.

Run the query for a year, for example: `./run_bq.sh cncf 2018-07-01 2019-07-01`. It takes about 900GB and costs about $4.50.

It will generate a file for example: `data/data_cncf_projects_20180701_20190701.csv`.

- You can optionally compare commits counts from BigQuery to git commits counts via: `PG_PASS=... ./shells/get_git_commits_count.sh proj_db YYYY-MM-DD YYYY-MM-DD`.
- You can optionally compare commits counts from BigQuery to DevStats commits counts via: `PG_PASS=... ./shells/get_devstats_commits_count.sh proj_db YYYY-MM-DD YYYY-MM-DD`.

Run `analysis.rb` with (you may lack CSV header, use `org,repo,activity,comments,prs,commits,issues,authors_alt2,authors_alt1,authors,pushes` in this case):
```
ruby analysis.rb data/data_cncf_projects_20190201_20200201.csv projects/projects_cncf_20190201_20200201.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv
```

Some projects are defined as regexps inside one or more orgs - BQ query tracks their orgs and config specifies which repos go to which project. You need to remove remaining repos for those orgs from the report.

Currently manually check for `oam-dev`, `layer5io` and `pixie-labs` in `projects/projects_20190201_20200201.csv` file.

Now update commits counts to use git instead of BigQuery data: (remember to update `devstats:util_sql/only_bots.sql`).

- Create `devstats-reports` pod, shell into it and run: `./velocity/update_cncf_projects_commits.sh 2019-02-01 2020-02-01`.
- Download update: `wget https://teststats.cncf.io/backups/data_cncf_update_2019-02-01_2020-02-01.csv`. `mv data_cncf_update_2019-02-01_2020-02-01.csv data/`.
- `ruby update_projects.rb projects/projects_cncf_20190201_20200201.csv data/data_cncf_update_2019-02-01_2020-02-01.csv -1`.

If you have all CNCF projects databases locally, you can use old local approach to get commits count updates:

- `PG_PASS=... ./update_cncf_projects_commits.rb 2018-07-01 2019-07-01`.

To compare CNCF K8s data vs non-k8s data do `ruby analysis.rb data/data_cncf_projects_20170801_20180801.csv projects/projects_cncf_k8s_non_k8s_20170101_20180801.csv map/hints_k8s_non_k8s.csv map/urls_k8s_non_k8s.csv map/defmaps_k8s_non_k8s.csv map/skip.csv map/ranges_sane.csv`.

Make a copy of the [google sheet](https://docs.google.com/spreadsheets/d/1KiMOYGO1nFO9Sq9mBdCEx16nd5ykqe6ngPZQ23nP1wo/edit?usp=sharing).

Put results of the analysis into a file and import the data in the 'Data' sheet in cell H1. <br />
File -> Import -> Upload -> in the Import location section, select the radio button called 'Replace data at selected cell', click Import data

Select the Chart tab, it will be updated automatically

A gist describing this process is at https://gist.github.com/lukaszgryglicki/093ced06455a3f14f0e4d25459525207

Use [this sheet](https://docs.google.com/spreadsheets/d/1j_L8AL137U8R3TclNo9b79m2r0nZi3b484PAqqeY-H8/edit?usp=sharing) for K8s vs. Non-K8s comparisoion.

### CNCF Projects split by Kubernetes VS rest
For this case, a new set of map files was created:
- `map/k8s_vs_rest_defmaps.csv` - list of orgs found in query
- `map/k8s_vs_rest_urls.csv` - definition of k8s vs rest
- `map/k8s_vs_rest_hints.csv` - list of repos found in query

Lists of orgs/repos in the map files should contain all values used in any period query.

It should be noted that historically, as CNCF grows, new projects are added. To get data for 2016, a query similar to that in `BigQuery/query_cncf_4p_201511_201610.sql` should be run and the following year would be span by `BigQuery/query_cncf_projects_201611_201710.sql`.
To prepare an analysis, a command similar to this should be run:
```
ruby analysis.rb data/data_cncf_projects_201611_201710.csv projects/projects_cncf_k8s_vs_rest_201611_201710.csv map/k8s_vs_rest_hints.csv map/k8s_vs_rest_urls.csv map/k8s_vs_rest_defmaps.csv map/skip.csv map/ranges_unlimited.csv
```
